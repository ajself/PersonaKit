(() => {
  const nodes = Array.from(document.querySelectorAll('.reveal'));
  nodes.forEach((node, i) => {
    node.style.transitionDelay = `${Math.min(i * 80, 320)}ms`;
  });

  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add('is-visible');
          observer.unobserve(entry.target);
        }
      });
    },
    { threshold: 0.2 }
  );

  nodes.forEach((node) => observer.observe(node));
})();
