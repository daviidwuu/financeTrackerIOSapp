import re
import os

input_file = 'FinanceTracker/Views/Onboarding/OnboardingView.swift'
steps_dir = 'FinanceTracker/Views/Onboarding/Steps'
models_dir = 'FinanceTracker/Models'

os.makedirs(steps_dir, exist_ok=True)
os.makedirs(models_dir, exist_ok=True)

with open(input_file, 'r') as f:
    content = f.read()

# Models inside OnboardingView
models = ['OnboardingCategory', 'OnboardingSavingGoal']
extracted_models = ""

for model in models:
    # Need to properly extract struct definition with brace counting
    start_match = re.search(r'    struct ' + model + r': Identifiable \{', content)
    if not start_match: continue
    start_idx = start_match.start()
    
    brace_count = 0
    in_struct = False
    end_idx = start_idx
    for i in range(start_idx, len(content)):
        if content[i] == '{':
            in_struct = True
            brace_count += 1
        elif content[i] == '}':
            brace_count -= 1
            if in_struct and brace_count == 0:
                end_idx = i + 1
                break
    model_content = content[start_idx:end_idx]
    
    # We un-indent the model content before saving
    lines = [line[4:] if line.startswith('    ') else line for line in model_content.split('\n')]
    extracted_models += '\n'.join(lines) + '\n\n'
    
    # Replace in content: since it's nested and used as OnboardingCategory, if we un-nest it we just delete it from OnboardingView
    content = content.replace(model_content, '')

if extracted_models:
    model_path = os.path.join(models_dir, 'OnboardingModels.swift')
    with open(model_path, 'w') as f:
        f.write("import Foundation\nimport SwiftUI\n\n" + extracted_models)
    print("Extracted Onboarding models")

# Now extract the steps (which are outside OnboardingView)
steps = [
    'IntroStep',
    'ProfileStep',
    'UsernameStep',
    'IncomeStep',
    'CategoriesStep',
    'EditCategorySheet',
    'AccountStep'
]

for step in steps:
    start_match = re.search(r'^struct ' + step + r': View \{', content, re.MULTILINE)
    if not start_match: 
        print(f"Could not find {step}")
        continue
    start_idx = start_match.start()
    
    brace_count = 0
    in_struct = False
    end_idx = start_idx
    for i in range(start_idx, len(content)):
        if content[i] == '{':
            in_struct = True
            brace_count += 1
        elif content[i] == '}':
            brace_count -= 1
            if in_struct and brace_count == 0:
                end_idx = i + 1
                break
    step_content = content[start_idx:end_idx]
    
    out_path = os.path.join(steps_dir, f'{step}.swift')
    with open(out_path, 'w') as f:
        f.write("import SwiftUI\n\n" + step_content + "\n")
    print(f"Extracted {step}")
    content = content.replace(step_content, '')

with open(input_file, 'w') as f:
    f.write(content.strip() + '\n')
print("Updated OnboardingView.swift")
