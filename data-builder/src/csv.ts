function parseCSVRow(line: string): string[] {
  const fields: string[] = [];
  let current = "";
  let inQuotes = false;

  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (inQuotes) {
      if (ch === '"') {
        if (i + 1 < line.length && line[i + 1] === '"') {
          current += '"';
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        current += ch;
      }
    } else {
      if (ch === '"') {
        inQuotes = true;
      } else if (ch === ",") {
        fields.push(current);
        current = "";
      } else {
        current += ch;
      }
    }
  }
  fields.push(current);
  return fields;
}

/** Split CSV text into logical records, respecting quoted newlines per RFC 4180. */
function splitCSVRecords(text: string): string[] {
  const records: string[] = [];
  let current = "";
  let inQuotes = false;

  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (inQuotes) {
      if (ch === '"') {
        if (i + 1 < text.length && text[i + 1] === '"') {
          current += '""';
          i++;
        } else {
          inQuotes = false;
          current += ch;
        }
      } else {
        current += ch;
      }
    } else {
      if (ch === '"') {
        inQuotes = true;
        current += ch;
      } else if (ch === "\n") {
        if (current.trim().length > 0) {
          records.push(current);
        }
        current = "";
      } else if (ch === "\r") {
        // skip \r (handle \r\n)
      } else {
        current += ch;
      }
    }
  }
  if (current.trim().length > 0) {
    records.push(current);
  }
  return records;
}

export function parseCSV(text: string): Record<string, string>[] {
  const lines = splitCSVRecords(text);
  if (lines.length === 0) return [];
  const headers = parseCSVRow(lines[0]);
  const rows: Record<string, string>[] = [];
  for (let i = 1; i < lines.length; i++) {
    const values = parseCSVRow(lines[i]);
    const row: Record<string, string> = {};
    for (let j = 0; j < headers.length; j++) {
      row[headers[j]] = values[j] ?? "";
    }
    rows.push(row);
  }
  return rows;
}

/**
 * Extract complete CSV records from a buffer, respecting quoted newlines.
 * Returns [completeRecords, remainingBuffer].
 */
function extractCSVRecords(buffer: string): [string[], string] {
  const records: string[] = [];
  let current = "";
  let inQuotes = false;

  for (let i = 0; i < buffer.length; i++) {
    const ch = buffer[i];
    if (inQuotes) {
      if (ch === '"') {
        if (i + 1 < buffer.length && buffer[i + 1] === '"') {
          current += '""';
          i++;
        } else {
          inQuotes = false;
          current += ch;
        }
      } else {
        current += ch;
      }
    } else {
      if (ch === '"') {
        inQuotes = true;
        current += ch;
      } else if (ch === "\n") {
        if (current.trim().length > 0) {
          records.push(current);
        }
        current = "";
      } else if (ch === "\r") {
        // skip \r
      } else {
        current += ch;
      }
    }
  }

  // If we're inside quotes, the record is incomplete — return it as remaining buffer
  if (inQuotes) {
    return [records, current];
  }

  return [records, current];
}

export async function* streamCSVLines(
  path: string,
): AsyncGenerator<Record<string, string>> {
  const file = Bun.file(path);
  if (!(await file.exists())) {
    throw new Error(`Failed to read file: ${path}\nFile does not exist`);
  }
  const stream = file.stream();
  const decoder = new TextDecoder();
  let buffer = "";
  let headers: string[] | null = null;

  for await (const chunk of stream) {
    buffer += decoder.decode(chunk, { stream: true });
    const [records, remaining] = extractCSVRecords(buffer);
    buffer = remaining;

    for (const record of records) {
      if (!headers) {
        headers = parseCSVRow(record);
        continue;
      }

      const values = parseCSVRow(record);
      const row: Record<string, string> = {};
      for (let j = 0; j < headers.length; j++) {
        row[headers[j]] = values[j] ?? "";
      }
      yield row;
    }
  }

  // flush remaining buffer
  if (buffer.trim().length > 0 && headers) {
    const values = parseCSVRow(buffer.trim());
    const row: Record<string, string> = {};
    for (let j = 0; j < headers.length; j++) {
      row[headers[j]] = values[j] ?? "";
    }
    yield row;
  }
}
