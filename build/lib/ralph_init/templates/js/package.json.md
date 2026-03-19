{
  "name": "{{PROJECT_NAME}}",
  "version": "0.0.0",
  "type": "module",
  "scripts": {
    "dev": "bun run --watch src/index.ts",
    "build": "bun build src/index.ts --outdir dist",
    "test": "bun test",
    "lint": "bunx biome check .",
    "format": "bunx biome format . --write"
  },
  "devDependencies": {
    "@biomejs/biome": "latest",
    "typescript": "latest"
  }
}
