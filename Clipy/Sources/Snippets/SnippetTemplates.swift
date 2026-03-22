//
//  SnippetTemplates.swift
//
//  Clipy
//
//  Built-in script snippet templates for common workflows.
//

import Foundation

struct SnippetTemplate: Identifiable {
    let id = UUID().uuidString
    let name: String
    let description: String
    let category: String
    let icon: String
    let shell: String
    let content: String
    let timeout: Int
}

struct SnippetTemplateLibrary {

    static let templates: [SnippetTemplate] = [
        // MARK: - AWS
        // Each template uses hardcoded config — edit PROFILE/SECRET_NAME after adding.
        // Recommended: place AWS snippets in a Vault folder (Touch ID protected).
        SnippetTemplate(
            name: "AWS SSO Credentials (env vars)",
            description: "Auto-refreshes SSO session and pastes credentials as export statements. Edit PROFILE below.",
            category: "AWS",
            icon: "cloud.fill",
            shell: "/bin/bash",
            content: """
            #!/bin/bash
            # ✏️ Set your AWS profile name here:
            PROFILE="your-profile-name"

            # Auto-authenticate if session expired
            if ! aws sts get-caller-identity --profile "$PROFILE" &>/dev/null; then
                aws sso login --profile "$PROFILE" >&2
            fi

            # Export credentials as env vars
            aws configure export-credentials --profile "$PROFILE" --format env 2>/dev/null || \\
                echo "# Failed to get credentials for profile: $PROFILE"
            """,
            timeout: 30
        ),

        SnippetTemplate(
            name: "AWS Secret Fetch",
            description: "Fetches a secret from AWS Secrets Manager by name. Edit PROFILE and SECRET_NAME below.",
            category: "AWS",
            icon: "lock.shield.fill",
            shell: "/bin/bash",
            content: """
            #!/bin/bash
            # ✏️ Configure your AWS profile and secret:
            PROFILE="your-profile-name"
            SECRET_NAME="your/secret/name"

            # Auto-authenticate if session expired
            if ! aws sts get-caller-identity --profile "$PROFILE" &>/dev/null; then
                aws sso login --profile "$PROFILE" >&2
            fi

            # Fetch the secret value
            aws secretsmanager get-secret-value \\
                --profile "$PROFILE" \\
                --secret-id "$SECRET_NAME" \\
                --query 'SecretString' \\
                --output text 2>/dev/null || \\
                echo "[Failed to fetch secret: $SECRET_NAME]"
            """,
            timeout: 15
        ),

        SnippetTemplate(
            name: "AWS Secret Field (JSON key)",
            description: "Fetches a JSON secret and extracts a specific field. Edit PROFILE, SECRET_NAME, and FIELD.",
            category: "AWS",
            icon: "key.fill",
            shell: "/bin/bash",
            content: """
            #!/bin/bash
            # ✏️ Configure your AWS profile, secret, and JSON field:
            PROFILE="your-profile-name"
            SECRET_NAME="your/secret/name"
            FIELD="password"

            # Auto-authenticate if session expired
            if ! aws sts get-caller-identity --profile "$PROFILE" &>/dev/null; then
                aws sso login --profile "$PROFILE" >&2
            fi

            # Fetch secret and extract the field
            aws secretsmanager get-secret-value \\
                --profile "$PROFILE" \\
                --secret-id "$SECRET_NAME" \\
                --query 'SecretString' \\
                --output text 2>/dev/null | \\
                python3 -c "import sys,json; print(json.load(sys.stdin)['$FIELD'])" 2>/dev/null || \\
                echo "[Failed to fetch field '$FIELD' from secret: $SECRET_NAME]"
            """,
            timeout: 15
        ),

        SnippetTemplate(
            name: "AWS SSM Parameter",
            description: "Fetches a parameter from AWS Systems Manager Parameter Store. Edit PROFILE and PARAM_NAME.",
            category: "AWS",
            icon: "slider.horizontal.3",
            shell: "/bin/bash",
            content: """
            #!/bin/bash
            # ✏️ Configure your AWS profile and parameter path:
            PROFILE="your-profile-name"
            PARAM_NAME="/your/parameter/path"

            # Auto-authenticate if session expired
            if ! aws sts get-caller-identity --profile "$PROFILE" &>/dev/null; then
                aws sso login --profile "$PROFILE" >&2
            fi

            # Fetch the parameter value (with decryption for SecureString)
            aws ssm get-parameter \\
                --profile "$PROFILE" \\
                --name "$PARAM_NAME" \\
                --with-decryption \\
                --query 'Parameter.Value' \\
                --output text 2>/dev/null || \\
                echo "[Failed to fetch parameter: $PARAM_NAME]"
            """,
            timeout: 15
        ),

        // MARK: - JSON
        SnippetTemplate(
            name: "JSON Pretty Print",
            description: "Format clipboard JSON with indentation.",
            category: "Format",
            icon: "curlybraces",

            shell: "/bin/bash",
            content: """
            #!/bin/bash
            echo "$CLIPBOARD" | python3 -m json.tool 2>/dev/null || echo "$CLIPBOARD"
            """,
            timeout: 5
        ),

        SnippetTemplate(
            name: "JSON Minify",
            description: "Compress clipboard JSON to a single line.",
            category: "Format",
            icon: "curlybraces",

            shell: "/bin/bash",
            content: """
            #!/bin/bash
            echo "$CLIPBOARD" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin),separators=(',',':')))" 2>/dev/null || echo "$CLIPBOARD"
            """,
            timeout: 5
        ),

        // MARK: - Encoding
        SnippetTemplate(
            name: "Base64 Encode",
            description: "Base64-encode clipboard content.",
            category: "Encode",
            icon: "lock.fill",

            shell: "/bin/bash",
            content: """
            #!/bin/bash
            echo -n "$CLIPBOARD" | base64
            """,
            timeout: 5
        ),

        SnippetTemplate(
            name: "Base64 Decode",
            description: "Base64-decode clipboard content.",
            category: "Encode",
            icon: "lock.open.fill",

            shell: "/bin/bash",
            content: """
            #!/bin/bash
            echo -n "$CLIPBOARD" | base64 -d 2>/dev/null || echo "[Invalid base64]"
            """,
            timeout: 5
        ),

        SnippetTemplate(
            name: "URL Encode",
            description: "Percent-encode clipboard text for use in URLs.",
            category: "Encode",
            icon: "link",

            shell: "/bin/bash",
            content: """
            #!/bin/bash
            python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.stdin.read().strip()))" <<< "$CLIPBOARD"
            """,
            timeout: 5
        ),

        // MARK: - JWT
        SnippetTemplate(
            name: "JWT Decode Payload",
            description: "Decode a JWT token and extract the payload.",
            category: "Security",
            icon: "key.horizontal.fill",

            shell: "/bin/bash",
            content: """
            #!/bin/bash
            # Extract and decode JWT payload (second segment)
            PAYLOAD=$(echo -n "$CLIPBOARD" | cut -d. -f2)
            # Add padding if needed
            MOD=$((${#PAYLOAD} % 4))
            if [ $MOD -eq 2 ]; then PAYLOAD="${PAYLOAD}=="
            elif [ $MOD -eq 3 ]; then PAYLOAD="${PAYLOAD}="
            fi
            echo -n "$PAYLOAD" | base64 -d 2>/dev/null | python3 -m json.tool 2>/dev/null || echo "[Invalid JWT]"
            """,
            timeout: 5
        ),

        // MARK: - Conversion
        SnippetTemplate(
            name: "Epoch to Date",
            description: "Convert a Unix timestamp in clipboard to human-readable date.",
            category: "Convert",
            icon: "clock.fill",

            shell: "/bin/bash",
            content: """
            #!/bin/bash
            TIMESTAMP="$CLIPBOARD"
            # Handle millisecond timestamps
            if [ ${#TIMESTAMP} -gt 10 ]; then
                TIMESTAMP=$((TIMESTAMP / 1000))
            fi
            date -r "$TIMESTAMP" "+%Y-%m-%d %H:%M:%S %Z" 2>/dev/null || echo "[Invalid timestamp]"
            """,
            timeout: 5
        ),

        SnippetTemplate(
            name: "Markdown to HTML",
            description: "Convert Markdown clipboard content to HTML (requires python3-markdown).",
            category: "Convert",
            icon: "doc.richtext.fill",

            shell: "/bin/bash",
            content: """
            #!/bin/bash
            echo "$CLIPBOARD" | python3 -c "
            import sys
            try:
                import markdown
                print(markdown.markdown(sys.stdin.read()))
            except ImportError:
                print('[Install python3-markdown: pip3 install markdown]')
            " 2>/dev/null
            """,
            timeout: 5
        ),

        // MARK: - Generators
        SnippetTemplate(
            name: "Generate UUID",
            description: "Generate a fresh UUID v4.",
            category: "Generate",
            icon: "number",

            shell: "/bin/bash",
            content: """
            #!/bin/bash
            uuidgen | tr '[:upper:]' '[:lower:]'
            """,
            timeout: 5
        ),

        SnippetTemplate(
            name: "Generate Password",
            description: "Generate a random 24-character password.",
            category: "Generate",
            icon: "key.fill",

            shell: "/bin/bash",
            content: """
            #!/bin/bash
            LC_ALL=C tr -dc 'A-Za-z0-9!@#$%^&*' < /dev/urandom | head -c 24
            """,
            timeout: 5
        ),
    ]

    static let categories: [String] = Array(Set(templates.map(\.category))).sorted()

    static func templates(in category: String) -> [SnippetTemplate] {
        templates.filter { $0.category == category }
    }
}
