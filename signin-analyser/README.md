# Entra Sign-in Log Analyser

Browser-based tool for analysing Microsoft Entra ID sign-in log CSV exports across multiple users.
No server required — everything runs locally in your browser. No data leaves your machine.

## How to use

1. Open `index.html` in any modern browser
2. Add a user row for each account you want to analyse
3. Export sign-in logs from the [Entra portal](https://entra.microsoft.com):
   - **Identity > Users > Sign-in logs** — Interactive and Non-Interactive logs
   - **Identity > Applications > Enterprise apps > Sign-in logs** — Application logs
4. Drop the CSV exports into the corresponding slots
5. Stats, charts, and threat signals populate automatically

## Features

- Colour-coded per-user view across Interactive, Non-Interactive, and Application log types
- Summary stats: total sign-ins, success/failure rates, unique IPs, apps, locations, date range
- Charts: status breakdown, sign-ins over time, top applications, top locations
- Filters: user, type, status, application, location, date range, free-text search
- Threat signals: shared IPs, shared locations, high failure rate per user
- Export filtered results as CSV
- Paginated table with grouping by IP, location, or user

## Privacy

All processing happens in your browser. No data is sent anywhere.
CSV files are read locally and never leave your machine.

## Tech

Vanilla HTML/JS — no build step, no install.
Dependencies loaded from CDN with SRI integrity hashes:
- [PapaParse](https://www.papaparse.com/) — CSV parsing
- [Chart.js](https://www.chartjs.org/) — charts
