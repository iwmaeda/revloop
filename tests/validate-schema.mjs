// Validate one JSON document against one JSON Schema and answer with an exit
// code: 0 valid, 1 rejected by the schema, 2 could not run.
// The schema suite asserts that some documents are rejected, so 1 (rejected)
// and 2 (never ran) must stay different answers.
//
// Usage: node tests/validate-schema.mjs <schema.json> <document.json>
import { readFileSync } from 'node:fs'
import AjvModule from 'ajv/dist/2020.js'

const Ajv = AjvModule.default ?? AjvModule

const [schemaPath, docPath] = process.argv.slice(2)
if (!schemaPath || !docPath) {
  console.error('usage: validate-schema.mjs <schema.json> <document.json>')
  process.exit(2)
}

let schema, doc
try {
  schema = JSON.parse(readFileSync(schemaPath, 'utf8'))
  doc = JSON.parse(readFileSync(docPath, 'utf8'))
} catch (e) {
  console.error(`could not read or parse: ${e.message}`)
  process.exit(2)
}

let validate
try {
  validate = new Ajv({ strict: false, allErrors: true }).compile(schema)
} catch (e) {
  console.error(`schema does not compile: ${e.message}`)
  process.exit(2)
}

if (validate(doc)) process.exit(0)
for (const err of validate.errors) {
  console.error(`${err.instancePath || '/'} ${err.message}`)
}
process.exit(1)
