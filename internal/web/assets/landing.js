(() => {
  document.documentElement.classList.add("js");

  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const header = document.querySelector("[data-site-header]");
  const menuButton = document.querySelector("[data-menu-toggle]");
  const navigation = document.querySelector("[data-site-nav]");
  const story = document.querySelector("[data-story]");
  const stage = document.querySelector("[data-story-stage]");
  const steps = Array.from(document.querySelectorAll("[data-story-step]"));
  const progressBar = document.querySelector("[data-story-progress-bar]");
  const stageLabel = document.querySelector("[data-stage-label]");
  const stageCount = document.querySelector("[data-stage-count]");
  const stageCaption = document.querySelector("[data-stage-caption]");
  const stageCopy = [
    {
      label: "Set context",
      caption: "Bring in the notation, examples, and methods your course actually uses.",
    },
    {
      label: "Work it out",
      caption: "Start with your own reasoning and ask for the smallest useful hint when you get stuck.",
    },
    {
      label: "Check a step",
      caption: "Find the first point where the reasoning diverged and understand what kind of mistake it was.",
    },
    {
      label: "Lock it in",
      caption: "Solve a nearby problem independently, then schedule weak concepts for targeted review.",
    },
  ];

  if (menuButton && navigation) {
    menuButton.addEventListener("click", () => {
      const open = menuButton.getAttribute("aria-expanded") === "true";
      menuButton.setAttribute("aria-expanded", String(!open));
      navigation.classList.toggle("is-open", !open);
    });
    navigation.querySelectorAll("a").forEach((link) => {
      link.addEventListener("click", () => {
        menuButton.setAttribute("aria-expanded", "false");
        navigation.classList.remove("is-open");
      });
    });
  }

  const revealItems = Array.from(document.querySelectorAll("[data-reveal]"));
  if (reduceMotion || !("IntersectionObserver" in window)) {
    revealItems.forEach((item) => item.classList.add("is-visible"));
  } else {
    const revealObserver = new IntersectionObserver(
      (entries, observer) => {
        entries.forEach((entry) => {
          if (!entry.isIntersecting) return;
          entry.target.classList.add("is-visible");
          observer.unobserve(entry.target);
        });
      },
      { threshold: 0.14, rootMargin: "0px 0px -8%" },
    );
    revealItems.forEach((item) => revealObserver.observe(item));
  }

  function setActiveStep(index) {
    if (!stage || !steps.length || index < 0 || index >= stageCopy.length) return;
    stage.dataset.activeStep = String(index);
    steps.forEach((step, stepIndex) => step.classList.toggle("is-active", stepIndex === index));
    if (stageLabel) stageLabel.textContent = stageCopy[index].label;
    if (stageCount) stageCount.textContent = `${String(index + 1).padStart(2, "0")} / 04`;
    if (stageCaption) stageCaption.textContent = stageCopy[index].caption;
  }

  let scheduled = false;
  function updateScrollState() {
    scheduled = false;
    if (header) header.classList.toggle("is-scrolled", window.scrollY > 30);
    if (!story || !stage || !steps.length) return;

    const storyBounds = story.getBoundingClientRect();
    const travel = Math.max(storyBounds.height - window.innerHeight, 1);
    const progress = Math.max(0, Math.min(1, -storyBounds.top / travel));
    stage.style.setProperty("--story-progress", String(progress));
    if (progressBar) progressBar.setAttribute("aria-valuenow", String(Math.round(progress * 100)));

    const focusLine = window.innerHeight * 0.48;
    let activeIndex = 0;
    let nearestDistance = Number.POSITIVE_INFINITY;
    steps.forEach((step, index) => {
      const bounds = step.getBoundingClientRect();
      const center = bounds.top + bounds.height / 2;
      const distance = Math.abs(center - focusLine);
      if (distance < nearestDistance) {
        nearestDistance = distance;
        activeIndex = index;
      }
    });
    setActiveStep(activeIndex);
  }

  function scheduleScrollUpdate() {
    if (scheduled) return;
    scheduled = true;
    window.requestAnimationFrame(updateScrollState);
  }

  window.addEventListener("scroll", scheduleScrollUpdate, { passive: true });
  window.addEventListener("resize", scheduleScrollUpdate);
  setActiveStep(0);
  updateScrollState();

  if (!reduceMotion && window.matchMedia("(pointer: fine)").matches) {
    document.querySelectorAll("[data-tilt]").forEach((container) => {
      const panel = container.querySelector(".product-window");
      if (!panel) return;
      container.addEventListener("pointermove", (event) => {
        const bounds = container.getBoundingClientRect();
        const x = (event.clientX - bounds.left) / bounds.width - 0.5;
        const y = (event.clientY - bounds.top) / bounds.height - 0.5;
        panel.style.transform = `rotateY(${x * 7 - 5}deg) rotateX(${y * -6 + 3}deg) translate3d(${x * 4}px, ${y * 4}px, 0)`;
      });
      container.addEventListener("pointerleave", () => {
        panel.style.transform = "rotateY(-5deg) rotateX(3deg)";
      });
    });
  }
})();
