/**
 * C0 (keeping tab and newline), C1, DEL and the bidirectional controls removed, so library text cannot draw, move or
 * reorder anything where it is shown, over however many lines.
 */
export const sanitizeText = (s: string): string =>
  s.replace(/[\u0000-\u0008\u000B-\u001F\u007F-\u009F\u202A-\u202E\u2066-\u2069\u200E\u200F\u061C]/g, '')

/**
 * `sanitizeText` plus everything that moves or hides text on one line: newlines, tabs, the line and paragraph
 * separators, zero-width and invisible characters (soft hyphen, Mongolian vowel separator, invisible operators, Hangul
 * fillers), variation selectors and tag characters.
 */
export const sanitizeLine = (s: string): string =>
  sanitizeText(s).replace(
    /[\n\t\u2028\u2029\u200B-\u200D\u2060-\u2064\uFEFF\u00AD\u180E\u3164\u115F\u1160\uFE00-\uFE0F\u{E0000}-\u{E007F}]/gu,
    '',
  )
