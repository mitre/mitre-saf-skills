# Security Policy

## Reporting Security Issues

The MITRE SAF team takes security seriously. If you discover a security vulnerability in any skill, please report it responsibly.

### Contact Information

- **Email**: [saf-security@mitre.org](mailto:saf-security@mitre.org)
- **GitHub**: Use the [Security tab](https://github.com/mitre/mitre-saf-skills/security) to report vulnerabilities privately

### What to Include

When reporting security issues, please provide:

1. **Description** of the vulnerability
2. **Affected skill(s)** and file paths
3. **Steps to reproduce** the issue
4. **Potential impact** assessment
5. **Suggested fix** (if you have one)

### Response Timeline

- **Acknowledgment**: Within 48 hours
- **Initial Assessment**: Within 7 days
- **Fix Timeline**: Varies by severity

## Security Considerations for Skill Authors

Skills run with the same permissions as the agent that loads them. When contributing skills:

- **Never include secrets, API keys, or credentials** in skill files
- **Never hardcode absolute paths** to personal directories
- **Avoid downloading or executing code from external sources** without verification
- **Use relative paths** for all file references within the skill
- **Document external dependencies** in the `compatibility` frontmatter field
- **Pin versions** when referencing external tools or packages

## Supported Versions

| Version | Supported |
|---------|-----------|
| latest  | Yes       |
