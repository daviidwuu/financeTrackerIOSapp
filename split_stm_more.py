import re
import os

input_file = 'FinanceTracker/Managers/SocialTransactionManager.swift'
extensions_dir = 'FinanceTracker/Managers/Extensions'

with open(input_file, 'r') as f:
    content = f.read()

extractions = {
    'SocialTransactionManager+Deletion': [
        'func deleteSocialTransaction(groupTransaction:',
        'func deleteSocialTransaction(transaction:',
        'func deleteSplitRequestAndSync(request:'
    ],
    'SocialTransactionManager+Splits': [
        'func resolveSplitRequestAction(request:',
        'private func declineSplitRequest(request:',
        'func markSplitAsPaid(request: FirestoreModels.SplitRequest, currentUserId: String, currentUserName: String) async throws {',
        'func unmarkSplitAsPaid(request: FirestoreModels.SplitRequest, currentUserId: String) async throws {',
        'func unmarkSplitAsPaid(request: FirestoreModels.SplitRequest) async throws {',
        'func revertLinkedSplitIfNeeded(transaction:'
    ],
    'SocialTransactionManager+Guest': [
        'func mergeGuestToFriend(guestId:'
    ]
}

new_content = content

for ext_name, methods in extractions.items():
    ext_methods_code = []
    
    for method_sig_prefix in methods:
        # Find the method start anywhere in the file
        idx = new_content.find(method_sig_prefix)
        if idx == -1:
            print(f"Could not find {method_sig_prefix}")
            continue
            
        start_idx = new_content.rfind('func ', 0, idx + len(method_sig_prefix))
        if 'private ' in new_content[max(0, start_idx-10):start_idx]:
             real_start = new_content.rfind('private ', 0, start_idx)
             if real_start != -1: start_idx = real_start
        
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

