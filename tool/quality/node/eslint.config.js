import js from '@eslint/js';
import stylistic from '@stylistic/eslint-plugin';
import sonarjs from 'eslint-plugin-sonarjs';
import globals from 'globals';

export default [
  { ignores: ['**/build/**', '**/.gradle/**', '**/.kotlin/**'] },
  {
    files: ['**/*.{cjs,js,mjs}'],
    languageOptions: { globals: globals.node },
    linterOptions: { noInlineConfig: true, reportUnusedDisableDirectives: 'error' },
    plugins: { '@stylistic': stylistic, sonarjs },
    rules: {
      ...js.configs.recommended.rules,
      '@stylistic/indent': ['error', 2, { SwitchCase: 1 }],
      '@stylistic/quotes': ['error', 'single', { avoidEscape: true }],
      '@stylistic/semi': ['error', 'always'],
      '@stylistic/no-trailing-spaces': 'error',
      '@stylistic/eol-last': ['error', 'always'],
      '@stylistic/no-multiple-empty-lines': ['error', { max: 1, maxEOF: 0 }],
      'max-lines': ['error', { max: 500 }],
      'max-lines-per-function': ['error', { max: 100, IIFEs: true }],
      complexity: ['error', 20],
      'sonarjs/cognitive-complexity': ['error', 25],
      'max-params': ['error', 6],
      'max-depth': ['error', 4],
      'no-unused-vars': ['error', { args: 'all', caughtErrors: 'all' }],
      'no-unused-private-class-members': 'error',
    },
  },
];
