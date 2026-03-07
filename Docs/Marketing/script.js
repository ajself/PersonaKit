(() => {
  const revealNodes = Array.from(document.querySelectorAll(".reveal"));
  const timelineItems = Array.from(document.querySelectorAll(".timeline li"));

  revealNodes.forEach((node, index) => {
    node.style.transitionDelay = `${Math.min(index * 70, 280)}ms`;
  });

  const revealObserver = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-visible");
          revealObserver.unobserve(entry.target);
        }
      });
    },
    {
      threshold: 0.2,
    }
  );

  revealNodes.forEach((node) => revealObserver.observe(node));

  const timelineObserver = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-active");
        } else {
          entry.target.classList.remove("is-active");
        }
      });
    },
    {
      threshold: 0.65,
    }
  );

  timelineItems.forEach((item) => timelineObserver.observe(item));
})();
