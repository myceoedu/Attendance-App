import {
  copyFileSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { basename, join, resolve } from 'node:path';
import { execSync } from 'node:child_process';

const docsDirectory = resolve(import.meta.dirname, '..');
const pdfDirectory = join(docsDirectory, 'pdf');
const temporaryDirectory = mkdtempSync(join(tmpdir(), 'myrekod-manuals-'));

const manuals = [
  {
    fileName: 'myRekod_User_Manual.pdf',
    title: '# myRekod — User Manual\n\n**For employees and administrators**  \nEnglish · Easy to follow',
    sourceFiles: [
      'user/00_getting_started.md',
      'user/01_employee_guide.md',
      'user/02_admin_guide.md',
      'user/03_troubleshooting.md',
    ],
  },
  {
    fileName: 'myRekod_Developer_Handover.pdf',
    title: '# myRekod — Developer Handover Guide\n\n**For engineers taking over this project**',
    sourceFiles: [
      'developer/00_overview.md',
      'developer/01_setup_and_run.md',
      'developer/02_supabase_and_database.md',
      'developer/03_architecture.md',
      'developer/04_features_and_key_files.md',
      'developer/05_deploy_and_auth.md',
      'developer/06_handover_checklist.md',
    ],
  },
];

try {
  for (const manual of manuals) {
    const markdown = [
      manual.title,
      ...manual.sourceFiles.map((sourceFile) =>
        readFileSync(join(docsDirectory, sourceFile), 'utf8').trim(),
      ),
    ].join('\n\n---\n\n');
    const temporaryMarkdown = join(
      temporaryDirectory,
      basename(manual.fileName, '.pdf') + '.md',
    );
    const temporaryPdf = temporaryMarkdown.replace(/\.md$/, '.pdf');

    writeFileSync(temporaryMarkdown, `${markdown}\n`, 'utf8');
    execSync(`npx --yes md-to-pdf "${temporaryMarkdown.replaceAll('"', '\\"')}"`, {
      cwd: docsDirectory,
      stdio: 'inherit',
    });
    copyFileSync(temporaryPdf, join(pdfDirectory, manual.fileName));
    console.log(`Created pdf/${manual.fileName}`);
  }
} finally {
  rmSync(temporaryDirectory, { recursive: true, force: true });
}
