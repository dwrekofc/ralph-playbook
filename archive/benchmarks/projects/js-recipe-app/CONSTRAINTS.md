# Project Constraints

## App Description

A simple recipe sharing web app for managing a personal recipe collection with search, favorites, and tags.

## Tech Stack

- **Language:** TypeScript
- **Runtime:** Bun
- **Framework:** React + Vite

## UI

- **Type:** Web app
- **UI Framework:** React
- **Design System:** Tailwind CSS

## Database

- **Type:** SQL
- **Product:** SQLite
- **ORM/Driver:** Drizzle

## Auth

- **Type:** None (single-user app)

## Deployment

- **Target:** Local only

## Back-Pressure Commands

- **Build:** `bun run build`
- **Test:** `bun run test`
- **Lint:** `bunx eslint .`
- **Typecheck:** `bunx tsc --noEmit`
- **Format:** `bunx prettier --check .`

## Hard Requirements

- Must use Bun as the runtime (not Node)
- All data stored locally in SQLite
- No external API calls
