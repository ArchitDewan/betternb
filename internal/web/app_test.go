package web

import (
	"bytes"
	"image"
	"image/color"
	"image/png"
	"io"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"net/textproto"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
)

func TestCreateNotebookAddsItToNavigationAndOpensItsChat(t *testing.T) {
	server := newTestServer(t, t.TempDir())
	defer server.Close()

	request, err := http.NewRequest(http.MethodPost, server.URL+"/notebooks", nil)
	if err != nil {
		t.Fatalf("new create notebook request: %v", err)
	}
	client := &http.Client{CheckRedirect: func(_ *http.Request, _ []*http.Request) error { return http.ErrUseLastResponse }}
	response, err := client.Do(request)
	if err != nil {
		t.Fatalf("POST notebook: %v", err)
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusSeeOther {
		body, _ := io.ReadAll(response.Body)
		t.Fatalf("POST notebook status = %d, want %d; body: %s", response.StatusCode, http.StatusSeeOther, body)
	}

	location := response.Header.Get("Location")
	if !regexp.MustCompile(`^/notebooks/[a-f0-9]{32}$`).MatchString(location) {
		t.Fatalf("notebook redirect = %q, want generated notebook URL", location)
	}
	body := readBody(t, get(t, server.URL+location))
	for _, expected := range []string{"New notebook", "Research notebook", `aria-current="page"`} {
		if !strings.Contains(body, expected) {
			t.Errorf("new notebook page does not contain %q; body: %s", expected, body)
		}
	}
}

func TestNotebookNavigationRestoresEachConversation(t *testing.T) {
	dataDir := t.TempDir()
	first := newTestServer(t, dataDir)
	client := &http.Client{CheckRedirect: func(_ *http.Request, _ []*http.Request) error { return http.ErrUseLastResponse }}
	response, err := client.Post(first.URL+"/notebooks", "application/x-www-form-urlencoded", nil)
	if err != nil {
		t.Fatalf("POST notebook: %v", err)
	}
	newLocation := response.Header.Get("Location")
	response.Body.Close()
	newNotebookID := strings.TrimPrefix(newLocation, "/notebooks/")

	postMessage(t, first.URL, "research", "Message in research", "", "", nil)
	postMessage(t, first.URL, newNotebookID, "Message in the new notebook", "", "", nil)
	first.Close()

	second := newTestServer(t, dataDir)
	defer second.Close()
	researchBody := readBody(t, get(t, second.URL+"/notebooks/research"))
	newBody := readBody(t, get(t, second.URL+newLocation))
	if !strings.Contains(researchBody, "Message in research") || strings.Contains(researchBody, "Message in the new notebook") {
		t.Errorf("research conversation was not isolated; body: %s", researchBody)
	}
	if !strings.Contains(newBody, "Message in the new notebook") || strings.Contains(newBody, "Message in research") {
		t.Errorf("new notebook conversation was not restored independently; body: %s", newBody)
	}
}

func TestUnknownNotebookURLIsNotCreated(t *testing.T) {
	server := newTestServer(t, t.TempDir())
	defer server.Close()

	response := get(t, server.URL+"/notebooks/made-up-in-the-url")
	defer response.Body.Close()
	if response.StatusCode != http.StatusNotFound {
		t.Errorf("GET unknown notebook status = %d, want %d", response.StatusCode, http.StatusNotFound)
	}
}

func TestLegacyURLNotebookIsAddedToNavigation(t *testing.T) {
	dataDir := t.TempDir()
	legacyDir := filepath.Join(dataDir, "notebooks", "project_notes")
	if err := os.MkdirAll(legacyDir, 0o700); err != nil {
		t.Fatalf("create legacy notebook directory: %v", err)
	}
	legacyMessages := `[{"id":"legacy","text":"Preserved conversation","created_at":"2026-09-30T12:00:00Z"}]`
	if err := os.WriteFile(filepath.Join(legacyDir, "messages.json"), []byte(legacyMessages), 0o600); err != nil {
		t.Fatalf("write legacy messages: %v", err)
	}

	server := newTestServer(t, dataDir)
	defer server.Close()
	body := readBody(t, get(t, server.URL+"/notebooks/project_notes"))
	for _, expected := range []string{"Project notes", "Preserved conversation"} {
		if !strings.Contains(body, expected) {
			t.Errorf("migrated notebook page does not contain %q; body: %s", expected, body)
		}
	}
}

func TestImageMessagePersistsAcrossAppRestart(t *testing.T) {
	dataDir := t.TempDir()
	imageBytes := testPNG(t)

	first := newTestServer(t, dataDir)
	location := postMessage(t, first.URL, "research", "What does this diagram show?", "diagram.png", "image/png", imageBytes)
	first.Close()

	second := newTestServer(t, dataDir)
	defer second.Close()

	response := get(t, second.URL+location)
	body := readBody(t, response)
	if response.StatusCode != http.StatusOK {
		t.Fatalf("GET conversation status = %d, want %d; body: %s", response.StatusCode, http.StatusOK, body)
	}
	for _, expected := range []string{"What does this diagram show?", "diagram.png"} {
		if !strings.Contains(body, expected) {
			t.Errorf("conversation does not contain %q; body: %s", expected, body)
		}
	}

	imagePath := imageSource(t, body)
	imageResponse := get(t, second.URL+imagePath)
	defer imageResponse.Body.Close()
	gotImage, err := io.ReadAll(imageResponse.Body)
	if err != nil {
		t.Fatalf("read stored image: %v", err)
	}
	if imageResponse.StatusCode != http.StatusOK {
		t.Fatalf("GET image status = %d, want %d", imageResponse.StatusCode, http.StatusOK)
	}
	if got := imageResponse.Header.Get("Content-Type"); got != "image/png" {
		t.Errorf("image Content-Type = %q, want image/png", got)
	}
	if !bytes.Equal(gotImage, imageBytes) {
		t.Error("stored image bytes differ from upload")
	}
}

func TestAttachmentIsScopedToOwningNotebook(t *testing.T) {
	server := newTestServer(t, t.TempDir())
	defer server.Close()

	location := postMessage(t, server.URL, "research", "", "private.png", "image/png", testPNG(t))
	body := readBody(t, get(t, server.URL+location))
	imagePath := imageSource(t, body)
	wrongNotebookPath := strings.Replace(imagePath, "/notebooks/research/", "/notebooks/other/", 1)

	response := get(t, server.URL+wrongNotebookPath)
	defer response.Body.Close()
	if response.StatusCode != http.StatusNotFound {
		t.Errorf("GET image through another notebook status = %d, want %d", response.StatusCode, http.StatusNotFound)
	}
}

func TestMessageValidationErrors(t *testing.T) {
	tests := []struct {
		name        string
		text        string
		filename    string
		contentType string
		contents    []byte
		wantError   string
	}{
		{name: "empty", wantError: "Add a message or paste an image"},
		{name: "unsupported bytes", filename: "notes.png", contentType: "image/png", contents: []byte("not really an image"), wantError: "PNG, JPEG, GIF, or WebP"},
		{name: "oversized", filename: "huge.png", contentType: "image/png", contents: bytes.Repeat([]byte("x"), maxImageBytes+1), wantError: "10 MiB or smaller"},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			server := newTestServer(t, t.TempDir())
			defer server.Close()

			response := postMessageResponse(t, server.URL, "research", test.text, test.filename, test.contentType, test.contents)
			body := readBody(t, response)
			if response.StatusCode != http.StatusUnprocessableEntity {
				t.Fatalf("POST status = %d, want %d; body: %s", response.StatusCode, http.StatusUnprocessableEntity, body)
			}
			if !strings.Contains(body, test.wantError) {
				t.Errorf("response does not contain %q; body: %s", test.wantError, body)
			}
		})
	}
}

func TestSupportedImageSignatures(t *testing.T) {
	tests := []struct {
		name     string
		contents []byte
		wantType string
	}{
		{name: "PNG", contents: testPNG(t), wantType: "image/png"},
		{name: "JPEG", contents: []byte{0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 'J', 'F', 'I', 'F', 0x00, 0x01}, wantType: "image/jpeg"},
		{name: "GIF", contents: []byte("GIF89a\x01\x00\x01\x00\x00\x00\x00"), wantType: "image/gif"},
		{name: "WebP", contents: []byte("RIFF\x10\x00\x00\x00WEBPVP8 \x04\x00\x00\x00"), wantType: "image/webp"},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			got := http.DetectContentType(test.contents)
			if got != test.wantType {
				t.Fatalf("detected type = %q, want %q", got, test.wantType)
			}
			if !allowedImageType(got) {
				t.Errorf("supported type %q was rejected", got)
			}
		})
	}
}

func newTestServer(t *testing.T, dataDir string) *httptest.Server {
	t.Helper()
	app, err := New(Config{DataDir: dataDir})
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	return httptest.NewServer(app.Handler())
}

func postMessage(t *testing.T, baseURL, notebookID, text, filename, contentType string, contents []byte) string {
	t.Helper()
	response := postMessageResponse(t, baseURL, notebookID, text, filename, contentType, contents)
	defer response.Body.Close()
	if response.StatusCode != http.StatusSeeOther {
		body, _ := io.ReadAll(response.Body)
		t.Fatalf("POST status = %d, want %d; body: %s", response.StatusCode, http.StatusSeeOther, body)
	}
	return response.Header.Get("Location")
}

func postMessageResponse(t *testing.T, baseURL, notebookID, text, filename, contentType string, contents []byte) *http.Response {
	t.Helper()
	var body bytes.Buffer
	writer := multipart.NewWriter(&body)
	if err := writer.WriteField("text", text); err != nil {
		t.Fatalf("write text field: %v", err)
	}
	if filename != "" {
		header := make(textproto.MIMEHeader)
		header.Set("Content-Disposition", `form-data; name="image"; filename="`+filename+`"`)
		header.Set("Content-Type", contentType)
		part, err := writer.CreatePart(header)
		if err != nil {
			t.Fatalf("create image part: %v", err)
		}
		if _, err := part.Write(contents); err != nil {
			t.Fatalf("write image part: %v", err)
		}
	}
	if err := writer.Close(); err != nil {
		t.Fatalf("close multipart writer: %v", err)
	}

	request, err := http.NewRequest(http.MethodPost, baseURL+"/notebooks/"+url.PathEscape(notebookID)+"/messages", &body)
	if err != nil {
		t.Fatalf("new request: %v", err)
	}
	request.Header.Set("Content-Type", writer.FormDataContentType())
	client := &http.Client{CheckRedirect: func(_ *http.Request, _ []*http.Request) error { return http.ErrUseLastResponse }}
	response, err := client.Do(request)
	if err != nil {
		t.Fatalf("POST message: %v", err)
	}
	return response
}

func get(t *testing.T, rawURL string) *http.Response {
	t.Helper()
	response, err := http.Get(rawURL)
	if err != nil {
		t.Fatalf("GET %s: %v", rawURL, err)
	}
	return response
}

func readBody(t *testing.T, response *http.Response) string {
	t.Helper()
	defer response.Body.Close()
	body, err := io.ReadAll(response.Body)
	if err != nil {
		t.Fatalf("read response: %v", err)
	}
	return string(body)
}

func imageSource(t *testing.T, body string) string {
	t.Helper()
	const marker = `class="message-image" src="`
	start := strings.Index(body, marker)
	if start == -1 {
		t.Fatalf("message image not found in body: %s", body)
	}
	start += len(marker)
	end := strings.Index(body[start:], `"`)
	if end == -1 {
		t.Fatalf("message image src is malformed in body: %s", body)
	}
	return body[start : start+end]
}

func testPNG(t *testing.T) []byte {
	t.Helper()
	var buffer bytes.Buffer
	picture := image.NewRGBA(image.Rect(0, 0, 2, 2))
	picture.Set(0, 0, color.RGBA{R: 112, G: 92, B: 242, A: 255})
	if err := png.Encode(&buffer, picture); err != nil {
		t.Fatalf("encode png: %v", err)
	}
	return buffer.Bytes()
}
