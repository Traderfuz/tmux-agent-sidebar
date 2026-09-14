<!-- source: profile:cli -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/cli/standards/global/modular-integration.md and re-run profile-sync. -->
# Modular Integration Standards — CLI Profile

Extends: [../../../general/standards/global/modular-integration.md](../../../general/standards/global/modular-integration.md)

## Overview

The default profile's modular integration standard covers frontend micro-frontends and backend service communication. CLI tools have a different modularity problem: **command surface explosion**. As a CLI grows, commands accumulate in a single entry file, business logic bleeds into argument handlers, and adding a new command requires touching the root program. The result is a tool that works but can't be extended without risk.

This standard applies the Plugin Pattern and Dependency Inversion Principle to CLI tools — keeping commands independently registerable, services swappable, and the main entry file minimal.

## Scope

This standard covers CLI plugin registration, command module structure, and service injection for TypeScript CLI tools using Bun + commander or clipanion. It does NOT cover HTTP service integration (see the default standard's API Integration Patterns), database module patterns, or frontend module federation.

## Principles

1. **Commands are plugins, not imports:** Each command registers itself into the program — the main entry file never contains command logic directly.
2. **Services are injected, not imported:** Commands receive services (logger, config, API client) as constructor arguments — never reach up to import singletons.
3. **One file, one command:** Each command lives in its own file. A command file exports one thing: the registration function.

## Rules

### Command module structure

**MUST follow the single-command-per-file pattern.** Each command exports a `register(program, services)` function.

**OFF-STANDARD — all commands in main entry:**
```typescript
// src/index.ts
const program = new Command();

program
  .command('build')
  .option('-o, --output <path>', 'Output path')
  .action((opts) => {
    // build logic inline
  });

program
  .command('deploy')
  .option('-e, --env <env>', 'Environment')
  .action((opts) => {
    // deploy logic inline
  });

program.parse();
```

**ON-STANDARD — each command in its own file:**
```typescript
// src/commands/build.ts
import type { Command } from 'commander';
import type { Services } from '../services/index.js';

interface BuildOptions {
  output: string;
  verbose: boolean;
}

export function register(program: Command, services: Services): void {
  program
    .command('build')
    .description('Build the project')
    .option('-o, --output <path>', 'Output path', 'dist')
    .option('-v, --verbose', 'Verbose output', false)
    .action(async (opts: BuildOptions) => {
      await services.builder.run(opts);
    });
}
```

```typescript
// src/index.ts — entry file stays minimal
import { Command } from 'commander';
import { createServices } from './services/index.js';
import { register as registerBuild } from './commands/build.js';
import { register as registerDeploy } from './commands/deploy.js';

const program = new Command();
const services = createServices();

registerBuild(program, services);
registerDeploy(program, services);

program.parse();
```

### Plugin loader pattern

**SHOULD use a plugin loader** when the command count exceeds 5, to avoid growing the entry file manually.

```typescript
// src/plugins/index.ts
import type { Command } from 'commander';
import type { Services } from '../services/index.js';

export interface CLIPlugin {
  name: string;
  register: (program: Command, services: Services) => void;
}

export function loadPlugins(
  program: Command,
  services: Services,
  plugins: CLIPlugin[]
): void {
  for (const plugin of plugins) {
    plugin.register(program, services);
  }
}
```

```typescript
// src/index.ts — with plugin loader
import { Command } from 'commander';
import { createServices } from './services/index.js';
import { loadPlugins } from './plugins/index.js';
import buildPlugin from './commands/build.js';
import deployPlugin from './commands/deploy.js';

const program = new Command();
const services = createServices();

loadPlugins(program, services, [buildPlugin, deployPlugin]);

program.parse();
```

### Service injection

**MUST NOT import mutable service singletons directly inside command files.** Services MUST be passed as arguments.

**OFF-STANDARD — singleton import inside command:**
```typescript
// src/commands/deploy.ts
import { logger } from '../logger.js';   // singleton — couples to implementation
import { apiClient } from '../api.js';   // can't swap in tests

export function register(program: Command): void {
  program.command('deploy').action(async () => {
    logger.info('Deploying...');
    await apiClient.deploy();
  });
}
```

**ON-STANDARD — services injected via interface:**
```typescript
// src/services/index.ts
export interface Services {
  logger: Logger;
  api: ApiClient;
  config: Config;
}

export function createServices(): Services {
  return {
    logger: new ConsoleLogger(),
    api: new ApiClient(process.env.API_KEY!),
    config: loadConfig(),
  };
}
```

```typescript
// src/commands/deploy.ts
import type { Command } from 'commander';
import type { Services } from '../services/index.js';

export function register(program: Command, { logger, api }: Services): void {
  program.command('deploy').action(async () => {
    logger.info('Deploying...');
    await api.deploy();
  });
}
```

### Context7 requirement

**MUST consult Context7 before integrating any external CLI library** (commander, clipanion, ink, ora, chalk, etc.):

```
1. mcp__context7__resolve-library-id("commander")
2. mcp__context7__query-docs("/tj/commander.js", "plugin pattern command registration")
```

Refer to the default standard's Common Integration Library IDs table for shared services (OpenAI, Anthropic, etc.).

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| All commands registered in `index.ts` | Entry file grows with every new command; increases merge conflicts | One file per command with `register(program, services)` |
| Mutable singleton imports in command files | Couples commands to concrete implementations; untestable | Pass services as arguments via `Services` interface |
| Plugin signature without `services` parameter | Commands must import singletons to function | Always pass `services` alongside `program` |
| Business logic inline in `.action()` handler | Untestable without invoking the CLI; mixes UI with logic | Extract to service method, call from `.action()` |
| Command file exports default class | Inconsistent registration; harder to tree-shake | Export named `register` function only |

## Deviation guidance

**MAY** register commands directly in `index.ts` (no plugin loader) when the tool has 3 or fewer commands and growth is not expected. MUST add the plugin loader before registering a 4th command.

**MAY** use module-level constants without injection — e.g., `const VERSION = '1.0.0'`, read-only environment config. MUST NOT use module-level singletons for mutable services (loggers, API clients, file system wrappers).

## Profile inheritance notes

Extends: `default/standards/global/modular-integration.md`
Adds: CLI plugin registration pattern, service injection contract, command-per-file structure rule.
Overrides: Scope — the default standard's frontend sections (Module Federation, micro-frontends) and backend service communication patterns do not apply to CLI tools.

## Compliance test

- [ ] Does each command live in its own file and export a named `register(program, services)` function?
- [ ] Does `index.ts` contain no business logic — only plugin registration and `program.parse()`?
- [ ] Do command files receive services as injected arguments — no mutable singleton imports?
- [ ] Is a `Services` interface defined and typed (in `src/services/index.ts` or equivalent)?
- [ ] Was Context7 consulted before integrating any new CLI library?

If any check fails: refactor the command to follow the plugin pattern, or record the deviation with a linked issue.

## References

- [Default modular integration standard](../../../default/standards/global/modular-integration.md) — base patterns for external service integration
- [commander.js](https://github.com/tj/commander.js) — plugin and subcommand registration patterns
- [SOLID — Dependency Inversion Principle](https://en.wikipedia.org/wiki/Dependency_inversion_principle) — high-level modules should not depend on low-level modules; both should depend on abstractions
