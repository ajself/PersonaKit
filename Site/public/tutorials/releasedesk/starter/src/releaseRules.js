export function requiredTasks(tasks) {
  return tasks.filter((task) => task.required);
}

export function blockedTasks(tasks) {
  return tasks.filter((task) => task.status === "blocked");
}

export function readinessSummary(tasks) {
  const required = requiredTasks(tasks);
  const incompleteRequired = required.filter((task) => {
    if (task.area === "security") {
      return false;
    }

    return task.status !== "done";
  });

  return {
    blockedCount: blockedTasks(tasks).length,
    incompleteRequiredCount: incompleteRequired.length,
    isReady: incompleteRequired.length === 0,
    requiredCount: required.length,
  };
}

export function filterTasks(tasks, area) {
  if (area === "all") {
    return tasks;
  }

  return tasks.filter((task) => task.area === area);
}

