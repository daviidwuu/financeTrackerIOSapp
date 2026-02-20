import re
import os

input_file = 'FinanceTracker/Views/Profile/ProfileSubviews.swift'
output_dir = 'FinanceTracker/Views/Profile/Settings'

with open(input_file, 'r') as f:
    content = f.read()

# Define the views to extract and their corresponding names
views = [
    'AccountSettingsView',
    'AppearanceSettingsView',
    'NotificationsSettingsView',
    'PrivacySettingsView',
    'HelpCenterView',
    'AboutView'
]

# We will split the file by "struct <ViewName>: View {"
# and capture everything inside properly using brace counting if needed,
# but it's easier to just split by the struct names since they appear sequentially.

extracted_files = []

for view in views:
    # Find the start of the struct
    start_match = re.search(r'struct ' + view + r': View \{', content)
    if not start_match:
        print(f"Could not find {view}")
        continue
    start_idx = start_match.start()
    
    # We find the end by looking for the next struct or end of file
    next_view_idx = len(content)
    for next_view in views:
        if next_view == view: continue
        match = re.search(r'struct ' + next_view + r': View \{', content[start_idx+1:])
        if match:
            candidate_idx = start_idx + 1 + match.start()
            if candidate_idx < next_view_idx:
                next_view_idx = candidate_idx
                
    view_content = content[start_idx:next_view_idx].strip()
    
    # Write to a new file
    out_path = os.path.join(output_dir, f'{view}.swift')
    with open(out_path, 'w') as f:
        f.write('import SwiftUI\nimport WidgetKit\n\n' + view_content + '\n')
    extracted_files.append(out_path)
    print(f"Extracted {view} to {out_path}")

# Now, we should write an empty or stripped ProfileSubviews.swift
# Or simply remove it using the ruby script.
