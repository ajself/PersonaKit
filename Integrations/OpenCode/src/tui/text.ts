/** C0 (keeping tab and newline), C1 and DEL removed, so library text cannot draw or move anything where it is shown. */
export const sanitizeText = (s: string): string => s.replace(/[\u0000-\u0008\u000B-\u001F\u007F-\u009F]/g, '')

/**
 * `sanitizeText` plus everything that moves or hides text on one line: newlines, tabs, the line and paragraph
 * separators, bidirectional controls and zero-width characters.
 */
export const sanitizeLine = (s: string): string =>
  sanitizeText(s).replace(/[\n\t\u2028\u2029\u202A-\u202E\u2066-\u2069\u200E\u200F\u061C\u200B-\u200D\u2060\uFEFF]/g, '')
