import re
import os

input_file = 'FinanceTracker/Views/Social/Groups/GroupDetailView.swift'
output_dir = 'FinanceTracker/Views/Social/Groups/Subviews'
os.makedirs(output_dir, exist_ok=True)

with open(input_file, 'r') as f:
    content = f.read()

# Models/Enums extraction if needed, but for now just the 4 Views
views = [
    'GroupHeaderSection',
    'DebtInstructionRow',
    'PendingSplitCard',
    'GroupTransactionRow'
]

# Extracting and replacing them from the original file
extracted_files = []
new_content = content

for view in views:
    pattern = r'(struct ' + view + r': View \{.*?\n\})[\n\r]*'
    # Use re.DOTALL to match across newlines inside the struct
    # Since structs might have nested braces, regex might be tricky.
    # We will use brace counting instead for safety.
    
    start_match = re.search(r'struct ' + view + r': View \{', content)
    if not start_match: continue
    
    start_idx = start_match.start()
    
    brace_count = 0
    in_struct = False
    end_idx = start_idx
    for i in range(start_idx, len(content)):
        if content[i] == '{':
            if not in_struct: in_struct = True
            brace_count += 1
        elif content[i] == '}':
            brace_count -= 1
            if brace_count == 0 and in_struct:
                end_idx = i + 1
                break
                
    view_content = content[start_idx:end_idx]
    
    # Save the view
    out_path = os.path.join(output_dir, f'{view}.swift')
    with open(out_path, 'w') as f:
        f.write('import SwiftUI\nimport FirebaseFirestore\n\n' + view_content + '\n')
    print(f"Extracted {view}")
    
    # Remove from original content
    new_content = new_content.replace(view_content, '')

# Save the stripped original file
with open(input_file, 'w') as f:
    f.write(new_content)
print("Updated GroupDetailView.swift")
