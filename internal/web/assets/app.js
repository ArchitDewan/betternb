(() => {
  const form = document.querySelector("[data-composer]");
  if (!form) return;

  const input = form.querySelector("[data-image-input]");
  const textarea = form.querySelector("[data-message-input]");
  const preview = form.querySelector("[data-image-preview]");
  const previewImage = form.querySelector("[data-preview-image]");
  const previewName = form.querySelector("[data-preview-name]");
  const removeButton = form.querySelector("[data-remove-image]");
  const error = form.querySelector("[data-client-error]");
  const sendButton = form.querySelector("[data-send-button]");
  const allowedTypes = new Set(["image/png", "image/jpeg", "image/gif", "image/webp"]);
  const maxBytes = 10 * 1024 * 1024;
  let previewURL;

  function showError(message) {
    error.textContent = message;
    error.hidden = !message;
  }

  function clearPreview() {
    if (previewURL) URL.revokeObjectURL(previewURL);
    previewURL = undefined;
    input.value = "";
    previewImage.removeAttribute("src");
    previewName.textContent = "";
    preview.hidden = true;
  }

  function renderFile(file) {
    showError("");
    if (!allowedTypes.has(file.type)) {
      clearPreview();
      showError("Paste a PNG, JPEG, GIF, or WebP image.");
      return false;
    }
    if (file.size > maxBytes) {
      clearPreview();
      showError("Choose an image that is 10 MiB or smaller.");
      return false;
    }
    if (previewURL) URL.revokeObjectURL(previewURL);
    previewURL = URL.createObjectURL(file);
    previewImage.src = previewURL;
    previewName.textContent = file.name || "Pasted image";
    preview.hidden = false;
    return true;
  }

  function selectPastedFile(file) {
    if (!renderFile(file)) return;
    const transfer = new DataTransfer();
    transfer.items.add(file);
    input.files = transfer.files;
  }

  form.addEventListener("paste", (event) => {
    const files = Array.from(event.clipboardData?.files || []);
    const image = files.find((file) => file.type.startsWith("image/"));
    if (!image) return;
    event.preventDefault();
    selectPastedFile(image);
  });

  input.addEventListener("change", () => {
    const file = input.files?.[0];
    if (file) renderFile(file);
    else clearPreview();
  });

  removeButton.addEventListener("click", () => {
    clearPreview();
    showError("");
    textarea.focus();
  });

  form.addEventListener("submit", (event) => {
    if (!textarea.value.trim() && !input.files?.length) {
      event.preventDefault();
      showError("Add a message or paste an image before sending.");
      textarea.focus();
      return;
    }
    sendButton.disabled = true;
    sendButton.querySelector("span").textContent = "Sending…";
  });
})();
