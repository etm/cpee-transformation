# cpee-transformation

## Dependencies

The Ruby dependencies (riddl, xml-smart, ...) are installed with the gem. The
BPMN2 target additionally needs
[cpee-layout](https://github.com/etm/cpee-layout) (Node.js >= 22.22), which is
not a gem dependency. By default it is run through `npx`, which fetches it on
first use (so the first BPMN2 request needs network access and is slow). To
avoid that, install it and point `trans.conf` to it (see BPMN2 target):

```sh
npm install -g cpee-layout
```

Without Node.js, everything except the `/bpmn2/...` routes works.

## Service

`cpee-trans new DIR` scaffolds the service into `DIR`: the server `trans` and
its config `trans.conf`, which is read from the same directory.

`trans` (port 9295) transforms process models. Routes are
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
from [cpee-layout](https://github.com/etm/cpee-layout), so the result is BPMN
with diagram interchange, laid out as drawn by cpee-layout. How `bpmnexport` is
run is set in `trans.conf`. The default (also without a setting) is

```yaml
:bpmnexport: npx -y -p cpee-layout@^1.2.0 bpmnexport
```

and after `npm install -g cpee-layout` it can be

```yaml
:bpmnexport: bpmnexport
```

A command name is searched in `PATH`, a path (containing `/`) is relative to
the directory of `trans`, `~` works too, e.g.
`~/Projects/cpee-layout/bin/bpmnexport` for a checkout. Arguments may follow, e.g. `bpmnexport -lr` for a left to
right layout.

`tools/cpee_to_bpmn2.rb FNAME` does the same on the command line, using the
`server/trans.conf` of the gem. If `bpmnexport` can't be run or fails, the request returns 500.
