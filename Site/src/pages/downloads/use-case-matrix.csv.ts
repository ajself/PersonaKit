import { useCaseMatrix } from "../../data/useCaseMatrix";

function escapeCsvValue(value: string): string {
  if (!/[",\n]/.test(value)) {
    return value;
  }

  return `"${value.replace(/"/g, '""')}"`;
}

export function GET() {
  const headers = [
    "Use case",
    "Fit",
    "Primary value",
    "Preferred surface",
    "Better tool when not PersonaKit",
  ];
  const rows = useCaseMatrix.map((row) => [
    row.useCase,
    row.fit,
    row.primaryValue,
    row.surface,
    row.alternative,
  ]);
  const csv = [
    headers,
    ...rows,
  ].map((row) => row.map(escapeCsvValue).join(",")).join("\n");

  return new Response(`${csv}\n`, {
    headers: {
      "Content-Disposition": 'attachment; filename="use-case-matrix.csv"',
      "Content-Type": "text/csv; charset=utf-8",
    },
  });
}
