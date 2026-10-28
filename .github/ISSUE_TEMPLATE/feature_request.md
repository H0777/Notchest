name: Feature request
about: Suggest a tool or improvement for Notchest
labels: ['enhancement']
body:
  - type: textarea
    id: problem
    attributes:
      label: What are you trying to do?
      description: The task or friction this feature would remove.
    validations:
      required: true
  - type: textarea
    id: solution
    attributes:
      label: What should it look like?
      description: Your idea of the solution, and any alternatives you considered.
    validations:
      required: true
  - type: input
    id: context
    attributes:
      label: Notchest version (if tried)
      placeholder: '0.5.0'
