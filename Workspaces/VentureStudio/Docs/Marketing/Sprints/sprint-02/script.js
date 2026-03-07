(() => {
  const reveals = Array.from(document.querySelectorAll('.reveal'));
  reveals.forEach((node, i) => {
    node.style.transitionDelay = `${Math.min(i * 90, 360)}ms`;
  });

  const io = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add('on');
          io.unobserve(entry.target);
        }
      });
    },
    { threshold: 0.22 }
  );

  reveals.forEach((node) => io.observe(node));
})();
