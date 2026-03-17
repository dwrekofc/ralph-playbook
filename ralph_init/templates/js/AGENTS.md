The role of this file is to describe common mistakes and confusion points that agents might encounter as they work in this project. 

If you ever encounter something in the project that surprises you, please alert the developer working with you and indicate that this is the case to help prevent future agents from having the same issue.

This project is super green field and no one is using it yet. we are focused on getting it in the right shape.

## Build & Run

- Runtime: Bun
- UI: shadcn/ui with Base UI primitives + Tailwind CSS
- Language: TypeScript (strict)
- Build: `bun run build`
- Dev: `bun run dev`

## Validation

- Tests: `bun test`
- Typecheck: `bun run tsc --noEmit`
- Lint: `bunx biome check .`
- Format: `bunx biome format . --write`

## Operational Notes

### Codebase Patterns
