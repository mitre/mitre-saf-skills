# Sphinx Documentation Conventions

## Directory Structure

```
docs/
├── conf.py           # Sphinx configuration
├── index.rst         # Root document (master toctree)
├── Makefile          # make html, make clean
├── requirements.txt  # Doc build deps
├── _static/          # Custom CSS, images
├── _templates/       # Jinja2 template overrides
├── getting-started/
│   ├── index.rst
│   └── installation.rst
└── api/
    └── index.rst     # autodoc output
```

## `conf.py` Configuration

```python
project = 'My Project'
release = '2.1.0'

extensions = [
    'sphinx.ext.autodoc',
    'sphinx.ext.napoleon',
    'sphinx.ext.intersphinx',
    'sphinx.ext.viewcode',
    'myst_parser',
]

html_theme = 'furo'

intersphinx_mapping = {
    'python': ('https://docs.python.org/3', None),
}

# Support both RST and Markdown
source_suffix = {'.rst': 'restructuredtext', '.md': 'markdown'}
myst_enable_extensions = ['colon_fence', 'deflist', 'tasklist']
```

## reStructuredText Basics

### Headings
```rst
Chapter Title
=============

Section
-------

Subsection
^^^^^^^^^^
```

### Toctree
```rst
.. toctree::
   :maxdepth: 2
   :caption: Contents

   getting-started/index
   api/index
   changelog
```

### Common Directives
```rst
.. note::
   Informational callout.

.. warning::
   Important warning.

.. code-block:: python
   :linenos:
   :emphasize-lines: 3

   def hello(name):
       return f"Hello, {name}!"

.. image:: _static/architecture.png
   :alt: Architecture diagram
   :width: 600px
```

### Cross-References
```rst
See :doc:`getting-started/installation` for setup.
The :func:`mypackage.core.process` function.
Refer to :ref:`custom-label` for details.
```

## MyST Markdown Alternative

Install: `pip install myst-parser`

```markdown
```{note}
Admonition in MyST syntax.
```

```{code-block} python
:linenos:
def hello():
    return "world"
```

{doc}`Link to doc <getting-started/installation>`
```

## Common Extensions

| Extension | Purpose |
|---|---|
| `sphinx.ext.autodoc` | Generate API docs from docstrings |
| `sphinx.ext.napoleon` | Google/NumPy docstring support |
| `sphinx.ext.intersphinx` | Cross-link to other Sphinx projects |
| `myst_parser` | Write docs in Markdown |
| `sphinx_copybutton` | Copy button on code blocks |

## Commands

```bash
make html              # Build HTML
make clean             # Remove artifacts
make linkcheck         # Verify links
sphinx-autobuild docs/ docs/_build/html  # Live reload dev server
sphinx-apidoc -o docs/api/ src/pkg/      # Generate API stubs
```

## Read the Docs

`.readthedocs.yaml`:
```yaml
version: 2
build:
  os: ubuntu-22.04
  tools:
    python: "3.12"
sphinx:
  configuration: docs/conf.py
  fail_on_warning: true
python:
  install:
    - requirements: docs/requirements.txt
```

## Common Gotchas

| Issue | Fix |
|---|---|
| `toctree contains reference to nonexisting document` | Paths are relative, no extension |
| Autodoc can't find module | Fix `sys.path` in conf.py |
| Heading underline too short | Must be >= heading text length |
| Directive body indentation | Must be exactly 3 spaces |
| Intersphinx links not resolving | Debug with `python -m sphinx.ext.intersphinx <url>/objects.inv` |
