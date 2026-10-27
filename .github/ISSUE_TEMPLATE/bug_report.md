name: Bug report
about: Report something broken in Notchest
labels: ['bug']
body:
  - type: markdown
    attributes:
      value: |
        Thanks for reporting. Please avoid pasting account tokens, API keys or
        other private data.
  - type: textarea
    id: what-happened
    attributes:
      label: What happened?
      description: Also tell us what you expected to happen instead.
    validations:
      required: true
  - type: textarea
    id: steps
    attributes:
      label: Steps to reproduce
      description: Numbered steps that reproduce the problem reliably.
      placeholder: |
        1.
        2.
    validations:
      required: true
  - type: input
    id: macos-version
    attributes:
      label: macOS version
      description: Apple menu → About This Mac.
      placeholder: 'macOS 15.7'
    validations:
      required: true
  - type: dropdown
    id: screen
    attributes:
      label: Screen setup
      options:
        - Built-in display with notch only
        - Built-in display + external monitor
        - External monitor only
        - Other / varies
    validations:
      required: true
  - type: input
    id: notchest-version
    attributes:
      label: Notchest version
      placeholder: '0.5'
    validations:
      required: true
  - type: textarea
    id: notes
    attributes:
      label: Anything else?
      description: Screenshots, Console output, or notes.
