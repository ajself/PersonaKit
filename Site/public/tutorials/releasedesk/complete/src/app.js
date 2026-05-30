import { filterTasks, readinessSummary } from "./releaseRules.js";

const embeddedData = {
  release: {
    name: "ReleaseDesk 1.4",
    date: "2026-06-12",
    owner: "Maya Chen",
  },
  tasks: [
    {
      id: "notes",
      title: "Publish release notes draft",
      area: "docs",
      owner: "Riley",
      required: true,
      status: "done",
      summary: "Customer-facing notes explain the dashboard filter changes.",
    },
    {
      id: "qa-smoke",
      title: "Run dashboard smoke test",
      area: "qa",
      owner: "Sam",
      required: true,
      status: "done",
      summary: "Core dashboard loads, filters tasks, and reports readiness.",
    },
    {
      id: "security-review",
      title: "Complete security review",
      area: "security",
      owner: "Priya",
      required: true,
      status: "blocked",
      summary: "Security review must sign off before a public release.",
      blocker: "Waiting for dependency disclosure notes.",
    },
    {
      id: "support-briefing",
      title: "Brief support team",
      area: "support",
      owner: "Ari",
      required: false,
      status: "todo",
      summary: "Support needs the customer-facing summary before launch.",
    },
    {
      id: "rollback-plan",
      title: "Confirm rollback plan",
      area: "release",
      owner: "Maya",
      required: true,
      status: "done",
      summary: "Rollback owner and checklist are ready.",
    },
  ],
};

const state = {
  area: "all",
  data: embeddedData,
};

function statusLabel(status) {
  if (status === "done") {
    return "Done";
  }

  if (status === "blocked") {
    return "Blocked";
  }

  return "To do";
}

function renderSummary() {
  const summary = readinessSummary(state.data.tasks);
  const readiness = document.querySelector("[data-readiness]");
  const detail = document.querySelector("[data-readiness-detail]");

  readiness.textContent = summary.isReady ? "Ready to ship" : "Not ready";
  readiness.className = summary.isReady ? "readiness ready" : "readiness blocked";
  detail.textContent = `${summary.incompleteRequiredCount} incomplete required task(s), ${summary.blockedCount} blocked task(s).`;
}

function emptyState(area) {
  return `
    <article class="empty-state">
      <h3>No ${area} tasks yet</h3>
      <p>This release does not have work in that area. Choose another filter or add a task before treating the release as reviewed.</p>
    </article>
  `;
}

function renderTasks() {
  const list = document.querySelector("[data-task-list]");
  const tasks = filterTasks(state.data.tasks, state.area);

  if (tasks.length === 0) {
    list.innerHTML = emptyState(state.area);

    return;
  }

  list.innerHTML = tasks.map((task) => `
    <article class="task-card ${task.status}">
      <div>
        <p class="task-area">${task.area}</p>
        <h3>${task.title}</h3>
        <p>${task.summary}</p>
        ${task.blocker ? `<p class="blocker">Blocker: ${task.blocker}</p>` : ""}
      </div>
      <div class="task-meta">
        <span>${task.owner}</span>
        <strong>${statusLabel(task.status)}</strong>
      </div>
    </article>
  `).join("");
}

function render() {
  document.querySelector("[data-release-name]").textContent = state.data.release.name;
  document.querySelector("[data-release-date]").textContent = state.data.release.date;
  document.querySelector("[data-release-owner]").textContent = state.data.release.owner;
  renderSummary();
  renderTasks();
}

document.querySelector("[data-area-filter]").addEventListener("change", (event) => {
  state.area = event.target.value;
  renderTasks();
});

render();

