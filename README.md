# cpee-transformation

## Dependencies

The Ruby dependencies (riddl, xml-smart, ...) are installed with the gem. The
BPMN2 target additionally needs
[cpee-layout](https://github.com/etm/cpee-layout) (Node.js >= 22.22), which is
not a gem dependency and has to be installed separately:

```sh
npm install -g cpee-layout
```

Without it, everything except the `/bpmn2/...` routes works.

## Service

`server/trans` (port 9295) transforms process models. Routes are
`/TARGET/SOURCE`, POSTed with the model as `description` and `type` set to
`description` (the transformed model), `dataelements` or `endpoints` (lists of
name/value pairs, from BPMN2 sources only).

| Route                       | Source   | Target                     |
| --------------------------- | -------- | -------------------------- |
| `/cpee/bpmn2`               | BPMN2    | CPEE                       |
| `/cpee/mermaid`             | mermaid  | CPEE                       |
| `/cpee/graphviz`            | graphviz | CPEE                       |
| `/bpmn2/cpee`               | CPEE     | BPMN2                      |
| `/bpmn2/mermaid`            | mermaid  | BPMN2                      |
| `/bpmn2/graphviz`           | graphviz | BPMN2                      |
| `/mermaid/cpee`             | CPEE     | mermaid                    |
| `/text-bf/cpee`             | CPEE     | text, text-bf              |
| `/text-df-PO-extended/cpee` | CPEE     | text, text-df-PO-extended  |
| `/text-df-PO-reduced/cpee`  | CPEE     | text, text-df-PO-reduced   |

```sh
curl -F 'description=@model.xml;type=text/xml' -F 'type=description' http://localhost:9295/bpmn2/cpee
```

### BPMN2 target

The BPMN2 target generates the CPEE model and lays it out with `bpmnexport`
from [cpee-layout](https://github.com/etm/cpee-layout) (`npm install -g
cpee-layout`), so the result is BPMN with diagram interchange, laid out as
drawn by cpee-layout. Where `bpmnexport` is found is set in `server/trans.conf`:

```yaml
:bpmnexport: bpmnexport
```

A command name is searched in `PATH`, a path (containing `/`) is relative to
the server directory, e.g. `../../cpee-layout/bin/bpmnexport` for a checkout
next to this one. Arguments may follow, e.g. `bpmnexport -lr` for a left to
right layout.

`tools/cpee_to_bpmn2.rb FNAME` does the same on the command line, using the
same `server/trans.conf`. If `bpmnexport` can't be run or fails, the request returns 500.
