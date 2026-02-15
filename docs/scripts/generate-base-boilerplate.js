#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

const repoRoot = path.resolve(__dirname, '..', '..');
const templatesDir = path.join(repoRoot, '.github', 'skills', 'nodejs-base-boilerplate', 'templates');

function readFileSafe(filePath) {
  return fs.readFileSync(filePath, 'utf8');
}

function ensureDir(dirPath) {
  fs.mkdirSync(dirPath, { recursive: true });
}

function writeIfMissing(filePath, content) {
  if (fs.existsSync(filePath)) return false;
  ensureDir(path.dirname(filePath));
  fs.writeFileSync(filePath, content, 'utf8');
  return true;
}

function writeFromTemplate(templateName, destPath) {
  const templatePath = path.join(templatesDir, templateName);
  const content = readFileSafe(templatePath);
  return writeIfMissing(destPath, content);
}

function main() {
  if (!fs.existsSync(templatesDir)) {
    console.error(`Templates dir not found: ${templatesDir}`);
    process.exit(1);
  }

  const created = [];

  if (writeFromTemplate('server.js.tmpl', path.join(repoRoot, 'server.js'))) {
    created.push('server.js');
  }
  if (writeFromTemplate('package.json.tmpl', path.join(repoRoot, 'package.json'))) {
    created.push('package.json');
  }
  if (writeFromTemplate('README.md.tmpl', path.join(repoRoot, 'README.md'))) {
    created.push('README.md');
  }
  if (writeFromTemplate('app.js.tmpl', path.join(repoRoot, 'src', 'app.js'))) {
    created.push('src/app.js');
  }
  if (writeFromTemplate('routes.index.js.tmpl', path.join(repoRoot, 'src', 'routes', 'index.js'))) {
    created.push('src/routes/index.js');
  }
  if (writeFromTemplate('middlewares.auth.js.tmpl', path.join(repoRoot, 'src', 'middlewares', 'auth.js'))) {
    created.push('src/middlewares/auth.js');
  }
  if (writeFromTemplate('middlewares.errorHandler.js.tmpl', path.join(repoRoot, 'src', 'middlewares', 'errorHandler.js'))) {
    created.push('src/middlewares/errorHandler.js');
  }
  if (writeFromTemplate('middlewares.notFound.js.tmpl', path.join(repoRoot, 'src', 'middlewares', 'notFound.js'))) {
    created.push('src/middlewares/notFound.js');
  }

  if (created.length === 0) {
    console.log('Base boilerplate ya existe. No se generaron archivos nuevos.');
    return;
  }

  console.log(`Base boilerplate generado: ${created.join(', ')}`);
}

main();
