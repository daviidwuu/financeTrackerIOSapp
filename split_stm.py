import re
import os

input_file = 'FinanceTracker/Managers/SocialTransactionManager.swift'
extensions_dir = 'FinanceTracker/Managers/Extensions'
os.makedirs(extensions_dir, exist_ok=True)

with open(input_file, 'r') as f:
    content = f.read()

# Define the methods to extract for each extension
extractions = {
    'SocialTransactionManager+Settlement': ['func settleUp('],
    'SocialTransactionManager+GroupManagement': ['func deleteGroup(', 'func leaveGroup(', 'func addMembersToGroup('],
    'SocialTransactionManager+Nudge': ['func sendNudge(', 'func hideSplitForUser('],
    'SocialTransactionManager+Guest': ['func mergeGuestTransactions(']
}

new_content = content

for ext_name, methods in extractions.items():
    ext_methods_code = []
    
    for method_sig in methods:
        # Find the method start
        # Use regex to find the exact signature ignoring leading spaces
        escaped_sig = method_sig.replace('(', r'\(')
        match = re.search(r'^[ \t]*' + escaped_sig, new_content, re.MULTILINE)
        if not match:
            print(f"Could not find {method_sig}")
            continue
            
        start_idx = match.start()
        
        # Brace counting to find end of method
        brace_count = 0
        in_method = False
        end_idx = start_idx
        for i in range(start_idx, len(new_content)):
            if new_content[i] == '{':
                in_method = True
                brace_count += 1
            elif new_content[i] == '}':
                brace_count -= 1
                if in_method and brace_count == 0:
                    end_idx = i + 1
                    break
                    
        method_code = new_content[start_idx:end_idx]
        ext_methods_code.append(method_code)
        
        # Remove from original content
        new_content = new_content.replace(method_code, '')
        
    if ext_methods_code:
        out_path = os.path.join(extensions_dir, f'{ext_name}.swift')
        with open(out_path, 'w') as f:
            f.write("import Foundation\nimport FirebaseFirestore\nimport FirebaseAuth\nimport Combine\n\n")
            f.write("extension SocialTransactionManager {\n\n")
            for code in ext_methods_code:
                f.write(code + "\n\n")
            f.write("}\n")
        print(f"Created {ext_name}.swift")

with open(input_file, 'w') as f:
    f.write(new_content)
print("Updated SocialTransactionManager.swift")

