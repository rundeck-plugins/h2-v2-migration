# Security Policy

## Repository Classification

This repository is classified as a **configuration-only repository** containing:

- Shell scripts for H2 database migration utilities
- Configuration files and test fixtures
- Documentation and operational tooling
- **No executable Node.js code or runtime dependencies**

## Security Posture

### Code Security
- This repository contains shell scripts that should be reviewed before execution
- The `migration.sh` script downloads H2 JAR files from Maven Central at runtime
- All scripts should be executed in controlled environments only

### Dependencies
- **No package manager dependencies** (npm, pip, maven, etc.) are used
- The `package.json` file exists solely for security scanning compliance
- Runtime dependencies are downloaded dynamically from trusted sources (Maven Central)

### Vulnerability Management

#### Scanning Approach
Since this repository contains no traditional dependencies, security scanning focuses on:
1. **Static Analysis**: Shell script best practices and security patterns
2. **File Permissions**: Ensuring proper execution permissions
3. **Source Verification**: Downloaded JAR files should be verified

#### Supported Versions
This repository supports migration between different H2 database versions as documented in the README.md.

| H2 Version | Rundeck Versions | Status |
| ---------- | ---------------- | ------ |
| v1 (1.4.200) | Up to 4.0.1 | Supported |
| v2 (2.1.212) | 4.1.0 to 4.17.x | Supported |
| v3 (2.2.220) | 5.0.0 and up | Supported |

### What to Include
- Description of the vulnerability
- Steps to reproduce the issue
- Potential impact assessment
- Suggested remediation (if known)

## Security Best Practices

### For Users
1. **Verify Sources**: Ensure you're using the official repository
2. **Review Scripts**: Always review shell scripts before execution
3. **Backup Data**: Create backups before running migration scripts
4. **Test Environment**: Run migrations in test environments first
5. **Verify Downloads**: Check integrity of downloaded JAR files

### For Contributors
1. **Shell Security**: Follow shell scripting security best practices
2. **Input Validation**: Validate all user inputs in scripts
3. **Error Handling**: Implement proper error handling
4. **Documentation**: Document security considerations in code

## Compliance

This repository maintains compliance with organizational security policies through:

- Minimal `package.json` for security scanner compatibility
- `.snyk` policy file documenting security posture
- Regular security documentation updates
- Clear classification as configuration-only repository

## Contact

For security-related questions or concerns:
- Security Team: security@rundeck.com
- Repository Maintainers: Via GitHub issues (for non-security items)

---

**Last Updated**: October 2025  
**Security Policy Version**: 1.0