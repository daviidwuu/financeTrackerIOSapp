import SwiftUI

struct LegalDocumentView: View {
    enum Document {
        case terms
        case privacy
    }
    
    let document: Document
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    private var title: String {
        switch document {
        case .terms:
            return "Terms of Service"
        case .privacy:
            return "Privacy Policy"
        }
    }
    
    private var markdown: String {
        switch document {
        case .terms:
            return """
            # Terms of Service
            
            These Terms of Service govern your use of the app.
            
            ## Subscriptions
            - The app may offer auto-renewable subscriptions (e.g., Monthly and Annual).
            - Payment is charged to your Apple ID account at confirmation of purchase.
            - Subscriptions automatically renew unless canceled at least 24 hours before the end of the current period.
            - You can manage and cancel subscriptions in your App Store account settings.
            - Any unused portion of a free trial, if offered, is forfeited when you purchase a subscription.
            
            ## Refunds
            Purchases and refunds are handled by Apple. For refund requests, use Apple’s purchase support and billing flows.
            
            ## App Functionality
            The app provides personal finance tracking features. You are responsible for reviewing and confirming any data you enter or import.
            
            ## Changes
            We may update these Terms from time to time. Continued use of the app after changes become effective constitutes acceptance of the updated Terms.
            
            ## Contact
            For support, use the in-app Help Center.
            """
        case .privacy:
            return """
            # Privacy Policy
            
            This Privacy Policy explains how the app handles information.
            
            ## Information You Provide
            - Account information (such as email and username) when you create an account.
            - Finance data you enter (such as transactions, budgets, and categories).
            
            ## Device and App Data
            - Diagnostic information may be collected to help improve stability and performance.
            - If you enable notifications, the app processes push notification tokens to deliver notifications.
            - If you enable location features, the app may use location to support travel-related functionality.
            
            ## Advertising
            If ads are shown in the app, advertising partners may process device identifiers and related information to deliver and measure ads, subject to your device settings and consent where required.
            
            ## Service Providers
            The app uses third-party services to provide core functionality, such as authentication, purchases/subscriptions, and (if enabled) advertising.
            
            ## Your Choices
            - You can manage subscription status via the App Store.
            - You can control notification permissions and (where applicable) tracking permissions in iOS Settings.
            
            ## Changes
            We may update this Privacy Policy from time to time.
            
            ## Contact
            For support, use the in-app Help Center.
            """
        }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            (colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Spacer().frame(height: 60)
                    
                    Text(.init(markdown))
                        .font(.body)
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, AppSpacing.margin)
                .padding(.bottom, 24)
            }
            
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .frame(width: 44, height: 44)
                        .background((colorScheme == .dark ? Color.white : Color.black).opacity(0.05))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
                Spacer()
                
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, AppSpacing.margin + AppSpacing.compact)
            .padding(.top, 16)
        }
    }
}

#Preview {
    LegalDocumentView(document: .terms)
}
