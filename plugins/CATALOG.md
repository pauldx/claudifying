# Plugins Catalog

**Total: 425 plugins** across 17 categories from [jeremylongshore/claude-code-plugins-plus-skills](https://github.com/jeremylongshore/claude-code-plugins-plus-skills)

Install any plugin via CLI:
```bash
ccpi install <plugin-name>
```

Or in Claude Code:
```
/plugin install <plugin-name>@claude-code-plugins-plus
```

---

## Table of Contents

- [DevOps](#devops) (35)
- [Security](#security) (26)
- [Testing](#testing) (26)
- [Performance](#performance) (25)
- [AI/ML](#ai-ml) (36)
- [AI Agency](#ai-agency) (8)
- [API Development](#api-development) (25)
- [Database](#database) (26)
- [Crypto & Blockchain](#crypto) (26)
- [Business Tools](#business-tools) (22)
- [SaaS Packs](#saas-packs) (107)
- [Productivity](#productivity) (22)
- [MCP](#mcp) (10)
- [Design](#design) (7)
- [Skill Enhancers](#skill-enhancers) (7)
- [Community](#community) (12)
- [Examples](#examples) (5)

---

## DevOps

**35 plugins**

| Plugin | Description | Install |
|--------|-------------|----------|
| **ansible-playbook-creator** | Create Ansible playbooks for configuration management | `ccpi install ansible-playbook-creator` |
| **auto-scaling-configurator** | Configure auto-scaling policies for applications and infrast... | `ccpi install auto-scaling-configurator` |
| **backup-strategy-implementor** | Implement backup strategies for databases and applications | `ccpi install backup-strategy-implementor` |
| **ci-cd-pipeline-builder** | Build CI/CD pipelines for GitHub Actions, GitLab CI, Jenkins... | `ccpi install ci-cd-pipeline-builder` |
| **cloud-cost-optimizer** | Optimize cloud costs and generate cost reports | `ccpi install cloud-cost-optimizer` |
| **compliance-checker** | Check infrastructure compliance (SOC2, HIPAA, PCI-DSS) | `ccpi install compliance-checker` |
| **container-registry-manager** | Manage container registries (ECR, GCR, Harbor) | `ccpi install container-registry-manager` |
| **container-security-scanner** | Scan containers for vulnerabilities using Trivy, Snyk, and o... | `ccpi install container-security-scanner` |
| **deployment-pipeline-orchestrator** | Orchestrate complex multi-stage deployment pipelines | `ccpi install deployment-pipeline-orchestrator` |
| **deployment-rollback-manager** | Manage and execute deployment rollbacks with safety checks | `ccpi install deployment-rollback-manager` |
| **disaster-recovery-planner** | Plan and implement disaster recovery procedures | `ccpi install disaster-recovery-planner` |
| **docker-compose-generator** | Generate Docker Compose configurations for multi-container a... | `ccpi install docker-compose-generator` |
| **engineer-design-diagram** | Generate production-grade engineering design diagrams (archi... | `ccpi install engineer-design-diagram` |
| **environment-config-manager** | Manage environment configurations and secrets across deploym... | `ccpi install environment-config-manager` |
| **fairdb-operations-kit** | Complete operations kit for FairDB PostgreSQL as a Service -... | `ccpi install fairdb-operations-kit` |
| **gh-dash** | GitHub PR dashboard for Claude Code. View PR status, CI/CD p... | `ccpi install gh-dash` |
| **git-commit-smart** | AI-powered conventional commit message generator with smart ... | `ccpi install git-commit-smart` |
| **gitops-workflow-builder** | Build GitOps workflows with ArgoCD and Flux | `ccpi install gitops-workflow-builder` |
| **helm-chart-generator** | Generate Helm charts for Kubernetes applications | `ccpi install helm-chart-generator` |
| **infrastructure-as-code-generator** | Generate Infrastructure as Code for Terraform, CloudFormatio... | `ccpi install infrastructure-as-code-generator` |
| **infrastructure-drift-detector** | Detect infrastructure drift from desired state | `ccpi install infrastructure-drift-detector` |
| **jeremy-adk-terraform** | Terraform infrastructure as code for ADK and Vertex AI Agent... | `ccpi install jeremy-adk-terraform` |
| **jeremy-genkit-terraform** | Terraform modules for Firebase Genkit infrastructure and dep... | `ccpi install jeremy-genkit-terraform` |
| **jeremy-github-actions-gcp** | GitHub Actions CI/CD workflows for Google Cloud and Vertex A... | `ccpi install jeremy-github-actions-gcp` |
| **jeremy-vertex-terraform** | Terraform configurations for Vertex AI platform and Agent En... | `ccpi install jeremy-vertex-terraform` |
| **kubernetes-deployment-creator** | Create Kubernetes deployments, services, and configurations ... | `ccpi install kubernetes-deployment-creator` |
| **load-balancer-configurator** | Configure load balancers (ALB, NLB, Nginx, HAProxy) | `ccpi install load-balancer-configurator` |
| **log-aggregation-setup** | Set up log aggregation (ELK, Loki, Splunk) | `ccpi install log-aggregation-setup` |
| **mattyp-changelog** | Automate changelog generation: fetch recent changes, synthes... | `ccpi install mattyp-changelog` |
| **monitoring-stack-deployer** | Deploy monitoring stacks (Prometheus, Grafana, Datadog) | `ccpi install monitoring-stack-deployer` |
| **network-policy-manager** | Manage Kubernetes network policies and firewall rules | `ccpi install network-policy-manager` |
| **secrets-manager-integrator** | Integrate with secrets managers (Vault, AWS Secrets Manager,... | `ccpi install secrets-manager-integrator` |
| **service-mesh-configurator** | Configure service mesh (Istio, Linkerd) for microservices | `ccpi install service-mesh-configurator` |
| **terraform-module-builder** | Build reusable Terraform modules | `ccpi install terraform-module-builder` |
| **tweetclaw** | X/Twitter automation - post, reply, like, retweet, follow, D... | `ccpi install tweetclaw` |

## Security

**26 plugins**

| Plugin | Description | Install |
|--------|-------------|----------|
| **access-control-auditor** | Audit access control implementations | `ccpi install access-control-auditor` |
| **authentication-validator** | Validate authentication implementations | `ccpi install authentication-validator` |
| **compliance-report-generator** | Generate compliance reports | `ccpi install compliance-report-generator` |
| **cors-policy-validator** | Validate CORS policies | `ccpi install cors-policy-validator` |
| **csrf-protection-validator** | Validate CSRF protection | `ccpi install csrf-protection-validator` |
| **data-privacy-scanner** | Scan for data privacy issues | `ccpi install data-privacy-scanner` |
| **dependency-checker** | Check dependencies for known vulnerabilities, outdated packa... | `ccpi install dependency-checker` |
| **encryption-tool** | Encrypt and decrypt data with various algorithms | `ccpi install encryption-tool` |
| **gdpr-compliance-scanner** | Scan for GDPR compliance issues | `ccpi install gdpr-compliance-scanner` |
| **hipaa-compliance-checker** | Check HIPAA compliance | `ccpi install hipaa-compliance-checker` |
| **input-validation-scanner** | Scan input validation practices | `ccpi install input-validation-scanner` |
| **owasp-compliance-checker** | Check OWASP Top 10 compliance | `ccpi install owasp-compliance-checker` |
| **pci-dss-validator** | Validate PCI DSS compliance | `ccpi install pci-dss-validator` |
| **penetration-tester** | Security testing toolkit with HTTP header analysis, dependen... | `ccpi install penetration-tester` |
| **secret-scanner** | Scan codebase for exposed secrets, API keys, passwords, and ... | `ccpi install secret-scanner` |
| **security-audit-reporter** | Generate comprehensive security audit reports | `ccpi install security-audit-reporter` |
| **security-headers-analyzer** | Analyze HTTP security headers | `ccpi install security-headers-analyzer` |
| **security-incident-responder** | Assist with security incident response | `ccpi install security-incident-responder` |
| **security-misconfiguration-finder** | Find security misconfigurations | `ccpi install security-misconfiguration-finder` |
| **session-security-checker** | Check session security implementation | `ccpi install session-security-checker` |
| **severity1-marketplace** | Severity level classification and prompt improvement for mar... | `ccpi install severity1-marketplace` |
| **soc2-audit-helper** | Assist with SOC2 audit preparation | `ccpi install soc2-audit-helper` |
| **sql-injection-detector** | Detect SQL injection vulnerabilities | `ccpi install sql-injection-detector` |
| **ssl-certificate-manager** | Manage and monitor SSL/TLS certificates | `ccpi install ssl-certificate-manager` |
| **vulnerability-scanner** | Comprehensive vulnerability scanning for code, dependencies,... | `ccpi install vulnerability-scanner` |
| **xss-vulnerability-scanner** | Scan for XSS vulnerabilities | `ccpi install xss-vulnerability-scanner` |

## Testing

**26 plugins**

| Plugin | Description | Install |
|--------|-------------|----------|
| **accessibility-test-scanner** | A11y compliance testing with WCAG 2.1/2.2 validation, screen... | `ccpi install accessibility-test-scanner` |
| **api-fuzzer** | Fuzz testing for APIs with malformed inputs, edge cases, and... | `ccpi install api-fuzzer` |
| **api-test-automation** | Automated API endpoint testing with request generation, vali... | `ccpi install api-test-automation` |
| **browser-compatibility-tester** | Cross-browser testing with Playwright, BrowserStack, Sauce L... | `ccpi install browser-compatibility-tester` |
| **chaos-engineering-toolkit** | Chaos testing for resilience with failure injection, latency... | `ccpi install chaos-engineering-toolkit` |
| **code-cleanup** | Comprehensive codebase cleanup across 11 quality dimensions ... | `ccpi install code-cleanup` |
| **contract-test-validator** | API contract testing with Pact, OpenAPI validation, and cons... | `ccpi install contract-test-validator` |
| **database-test-manager** | Database testing utilities with test data setup, transaction... | `ccpi install database-test-manager` |
| **e2e-test-framework** | End-to-end test automation with Playwright, Cypress, and Sel... | `ccpi install e2e-test-framework` |
| **integration-test-runner** | Run and manage integration test suites with environment setu... | `ccpi install integration-test-runner` |
| **load-balancer-tester** | Test load balancing strategies with traffic distribution val... | `ccpi install load-balancer-tester` |
| **mobile-app-tester** | Mobile app test automation with Appium, Detox, XCUITest - te... | `ccpi install mobile-app-tester` |
| **mutation-test-runner** | Mutation testing to validate test quality by introducing cod... | `ccpi install mutation-test-runner` |
| **performance-test-suite** | Load testing and performance benchmarking with metrics analy... | `ccpi install performance-test-suite` |
| **regression-test-tracker** | Track and run regression tests to ensure new changes don't b... | `ccpi install regression-test-tracker` |
| **security-test-scanner** | Automated security vulnerability testing covering OWASP Top ... | `ccpi install security-test-scanner` |
| **smoke-test-runner** | Quick smoke test suites to verify critical functionality aft... | `ccpi install smoke-test-runner` |
| **snapshot-test-manager** | Manage and update snapshot tests with intelligent diff analy... | `ccpi install snapshot-test-manager` |
| **test-coverage-analyzer** | Analyze code coverage metrics, identify untested code, and g... | `ccpi install test-coverage-analyzer` |
| **test-data-generator** | Generate realistic test data including users, products, orde... | `ccpi install test-data-generator` |
| **test-doubles-generator** | Generate mocks, stubs, spies, and fakes for unit testing wit... | `ccpi install test-doubles-generator` |
| **test-environment-manager** | Manage test environments with Docker Compose, Testcontainers... | `ccpi install test-environment-manager` |
| **test-orchestrator** | Orchestrate complex test workflows with dependencies, parall... | `ccpi install test-orchestrator` |
| **test-report-generator** | Generate comprehensive test reports with coverage, trends, a... | `ccpi install test-report-generator` |
| **unit-test-generator** | Automatically generate comprehensive unit tests from source ... | `ccpi install unit-test-generator` |
| **visual-regression-tester** | Visual diff testing with Percy, Chromatic, BackstopJS - catc... | `ccpi install visual-regression-tester` |

## Performance

**25 plugins**

| Plugin | Description | Install |
|--------|-------------|----------|
| **alerting-rule-creator** | Create intelligent alerting rules for performance monitoring | `ccpi install alerting-rule-creator` |
| **apm-dashboard-creator** | Create Application Performance Monitoring dashboards | `ccpi install apm-dashboard-creator` |
| **application-profiler** | Profile application performance with CPU, memory, and execut... | `ccpi install application-profiler` |
| **bottleneck-detector** | Detect and resolve performance bottlenecks | `ccpi install bottleneck-detector` |
| **cache-performance-optimizer** | Optimize caching strategies for improved performance | `ccpi install cache-performance-optimizer` |
| **capacity-planning-analyzer** | Analyze and plan for capacity requirements | `ccpi install capacity-planning-analyzer` |
| **cpu-usage-monitor** | Monitor and analyze CPU usage patterns in applications | `ccpi install cpu-usage-monitor` |
| **database-query-profiler** | Profile and optimize database queries for performance | `ccpi install database-query-profiler` |
| **distributed-tracing-setup** | Set up distributed tracing for microservices | `ccpi install distributed-tracing-setup` |
| **error-rate-monitor** | Monitor and analyze application error rates | `ccpi install error-rate-monitor` |
| **infrastructure-metrics-collector** | Collect comprehensive infrastructure performance metrics | `ccpi install infrastructure-metrics-collector` |
| **load-test-runner** | Create and execute load tests for performance validation | `ccpi install load-test-runner` |
| **log-analysis-tool** | Analyze logs for performance insights and issues | `ccpi install log-analysis-tool` |
| **memory-leak-detector** | Detect memory leaks and analyze memory usage patterns | `ccpi install memory-leak-detector` |
| **metrics-aggregator** | Aggregate and centralize performance metrics | `ccpi install metrics-aggregator` |
| **network-latency-analyzer** | Analyze network latency and optimize request patterns | `ccpi install network-latency-analyzer` |
| **performance-budget-validator** | Validate application against performance budgets | `ccpi install performance-budget-validator` |
| **performance-optimization-advisor** | Get comprehensive performance optimization recommendations | `ccpi install performance-optimization-advisor` |
| **performance-regression-detector** | Detect performance regressions in CI/CD pipeline | `ccpi install performance-regression-detector` |
| **real-user-monitoring** | Implement Real User Monitoring for actual performance data | `ccpi install real-user-monitoring` |
| **resource-usage-tracker** | Track and optimize resource usage across the stack | `ccpi install resource-usage-tracker` |
| **response-time-tracker** | Track and optimize application response times | `ccpi install response-time-tracker` |
| **sla-sli-tracker** | Track SLAs, SLIs, and SLOs for service reliability | `ccpi install sla-sli-tracker` |
| **synthetic-monitoring-setup** | Set up synthetic monitoring for proactive performance tracki... | `ccpi install synthetic-monitoring-setup` |
| **throughput-analyzer** | Analyze and optimize system throughput | `ccpi install throughput-analyzer` |

## AI/ML

**36 plugins**

| Plugin | Description | Install |
|--------|-------------|----------|
| **ai-ethics-validator** | AI ethics and fairness validation | `ccpi install ai-ethics-validator` |
| **ai-sdk-agents** | Multi-agent orchestration with AI SDK v5 - handoffs, routing... | `ccpi install ai-sdk-agents` |
| **anomaly-detection-system** | Detect anomalies and outliers in data | `ccpi install anomaly-detection-system` |
| **automl-pipeline-builder** | Build AutoML pipelines | `ccpi install automl-pipeline-builder` |
| **classification-model-builder** | Build classification models | `ccpi install classification-model-builder` |
| **clustering-algorithm-runner** | Run clustering algorithms on datasets | `ccpi install clustering-algorithm-runner` |
| **computer-vision-processor** | Computer vision image processing and analysis | `ccpi install computer-vision-processor` |
| **data-preprocessing-pipeline** | Automated data preprocessing and cleaning pipelines | `ccpi install data-preprocessing-pipeline` |
| **data-visualization-creator** | Create data visualizations and plots | `ccpi install data-visualization-creator` |
| **dataset-splitter** | Split datasets for training, validation, and testing | `ccpi install dataset-splitter` |
| **deep-learning-optimizer** | Deep learning optimization techniques | `ccpi install deep-learning-optimizer` |
| **experiment-tracking-setup** | Set up ML experiment tracking | `ccpi install experiment-tracking-setup` |
| **feature-engineering-toolkit** | Feature creation, selection, and transformation tools | `ccpi install feature-engineering-toolkit` |
| **hyperparameter-tuner** | Optimize hyperparameters using grid/random/bayesian search | `ccpi install hyperparameter-tuner` |
| **jeremy-adk-orchestrator** | Production ADK orchestrator for A2A protocol and multi-agent... | `ccpi install jeremy-adk-orchestrator` |
| **jeremy-adk-software-engineer** | ADK software engineer for creating production-ready agents w... | `ccpi install jeremy-adk-software-engineer` |
| **jeremy-gcp-starter-examples** | Google Cloud starter kits and example code aggregator with A... | `ccpi install jeremy-gcp-starter-examples` |
| **jeremy-genkit-pro** | Firebase Genkit expert for production-ready AI workflows wit... | `ccpi install jeremy-genkit-pro` |
| **jeremy-google-adk** | Google Agent Development Kit (ADK) SDK starter kit for build... | `ccpi install jeremy-google-adk` |
| **jeremy-vertex-ai** | Comprehensive Vertex AI integration plugin for building gene... | `ccpi install jeremy-vertex-ai` |
| **jeremy-vertex-engine** | Vertex AI Agent Engine deployment inspector and runtime vali... | `ccpi install jeremy-vertex-engine` |
| **jeremy-vertex-validator** | Production readiness validator for Vertex AI deployments and... | `ccpi install jeremy-vertex-validator` |
| **local-tts** | Offline text-to-speech via VoxCPM2 — 30 languages, voice des... | `ccpi install local-tts` |
| **ml-model-trainer** | Train and optimize machine learning models with automated wo... | `ccpi install ml-model-trainer` |
| **model-deployment-helper** | Deploy ML models to production | `ccpi install model-deployment-helper` |
| **model-evaluation-suite** | Comprehensive model evaluation with multiple metrics | `ccpi install model-evaluation-suite` |
| **model-explainability-tool** | Model interpretability and explainability | `ccpi install model-explainability-tool` |
| **model-versioning-tracker** | Track and manage model versions | `ccpi install model-versioning-tracker` |
| **neural-network-builder** | Build and configure neural network architectures | `ccpi install neural-network-builder` |
| **nlp-text-analyzer** | Natural language processing and text analysis | `ccpi install nlp-text-analyzer` |
| **ollama-local-ai** | Run AI models locally with Ollama - free alternative to Open... | `ccpi install ollama-local-ai` |
| **recommendation-engine** | Build recommendation systems and engines | `ccpi install recommendation-engine` |
| **regression-analysis-tool** | Regression analysis and modeling | `ccpi install regression-analysis-tool` |
| **sentiment-analysis-tool** | Sentiment analysis on text data | `ccpi install sentiment-analysis-tool` |
| **time-series-forecaster** | Time series forecasting and analysis | `ccpi install time-series-forecaster` |
| **transfer-learning-adapter** | Transfer learning adaptation | `ccpi install transfer-learning-adapter` |

## AI Agency

**8 plugins**

| Plugin | Description | Install |
|--------|-------------|----------|
| **discovery-questionnaire** | Generate custom discovery questionnaires for AI agency prosp... | `ccpi install discovery-questionnaire` |
| **make-scenario-builder** | Create Make.com (Integromat) scenarios with AI assistance - ... | `ccpi install make-scenario-builder` |
| **n8n-workflow-designer** | Design complex n8n workflows with AI assistance - loops, bra... | `ccpi install n8n-workflow-designer` |
| **roi-calculator** | Calculate and present ROI for AI automation projects | `ccpi install roi-calculator` |
| **shipwright** | Describe your app in plain English — Shipwright builds, test... | `ccpi install shipwright` |
| **sow-generator** | Generate professional Statements of Work for AI projects | `ccpi install sow-generator` |
| **tonone** | Engineering + Product team — 23 agents as Claude Code specia... | `ccpi install tonone` |
| **zapier-zap-builder** | Create multi-step Zapier Zaps with filters, paths, and forma... | `ccpi install zapier-zap-builder` |

## API Development

**25 plugins**

| Plugin | Description | Install |
|--------|-------------|----------|
| **api-authentication-builder** | Build authentication systems with JWT, OAuth2, and API keys | `ccpi install api-authentication-builder` |
| **api-batch-processor** | Implement batch API operations with bulk processing and job ... | `ccpi install api-batch-processor` |
| **api-cache-manager** | Implement caching strategies with Redis, CDN, and HTTP heade... | `ccpi install api-cache-manager` |
| **api-contract-generator** | Generate API contracts for consumer-driven contract testing | `ccpi install api-contract-generator` |
| **api-documentation-generator** | Generate comprehensive API documentation from OpenAPI/Swagge... | `ccpi install api-documentation-generator` |
| **api-error-handler** | Implement standardized error handling with proper HTTP statu... | `ccpi install api-error-handler` |
| **api-event-emitter** | Implement event-driven APIs with message queues and event st... | `ccpi install api-event-emitter` |
| **api-gateway-builder** | Build API gateway with routing, authentication, and rate lim... | `ccpi install api-gateway-builder` |
| **api-load-tester** | Load test APIs with k6, Gatling, or Artillery | `ccpi install api-load-tester` |
| **api-migration-tool** | Migrate APIs between versions with backward compatibility | `ccpi install api-migration-tool` |
| **api-mock-server** | Create mock API servers from OpenAPI specs for testing | `ccpi install api-mock-server` |
| **api-monitoring-dashboard** | Create monitoring dashboards for API health, metrics, and al... | `ccpi install api-monitoring-dashboard` |
| **api-rate-limiter** | Implement rate limiting with token bucket, sliding window, a... | `ccpi install api-rate-limiter` |
| **api-request-logger** | Log API requests with structured logging and correlation IDs | `ccpi install api-request-logger` |
| **api-response-validator** | Validate API responses against schemas and contracts | `ccpi install api-response-validator` |
| **api-schema-validator** | Validate API schemas with JSON Schema, Joi, Yup, or Zod | `ccpi install api-schema-validator` |
| **api-sdk-generator** | Generate client SDKs from OpenAPI specs for multiple languag... | `ccpi install api-sdk-generator` |
| **api-security-scanner** | Scan APIs for security vulnerabilities and OWASP API Top 10 | `ccpi install api-security-scanner` |
| **api-throttling-manager** | Manage API throttling with dynamic rate limits and quota man... | `ccpi install api-throttling-manager` |
| **api-versioning-manager** | Manage API versions with migration strategies and backward c... | `ccpi install api-versioning-manager` |
| **graphql-server-builder** | Build GraphQL servers with schema-first design, resolvers, a... | `ccpi install graphql-server-builder` |
| **grpc-service-generator** | Generate gRPC services with Protocol Buffers and streaming s... | `ccpi install grpc-service-generator` |
| **rest-api-generator** | Generate RESTful APIs from schemas with proper routing, vali... | `ccpi install rest-api-generator` |
| **webhook-handler-creator** | Create secure webhook endpoints with signature verification ... | `ccpi install webhook-handler-creator` |
| **websocket-server-builder** | Build WebSocket servers for real-time bidirectional communic... | `ccpi install websocket-server-builder` |

## Database

**26 plugins**

| Plugin | Description | Install |
|--------|-------------|----------|
| **data-seeder-generator** | Generate realistic test data and database seed scripts for d... | `ccpi install data-seeder-generator` |
| **data-validation-engine** | Database plugin for data-validation-engine | `ccpi install data-validation-engine` |
| **database-archival-system** | Database plugin for database-archival-system | `ccpi install database-archival-system` |
| **database-audit-logger** | Database plugin for database-audit-logger | `ccpi install database-audit-logger` |
| **database-backup-automator** | Automate database backups with scheduling, compression, encr... | `ccpi install database-backup-automator` |
| **database-cache-layer** | Database plugin for database-cache-layer | `ccpi install database-cache-layer` |
| **database-connection-pooler** | Implement and optimize database connection pooling for impro... | `ccpi install database-connection-pooler` |
| **database-deadlock-detector** | Database plugin for database-deadlock-detector | `ccpi install database-deadlock-detector` |
| **database-diff-tool** | Database plugin for database-diff-tool | `ccpi install database-diff-tool` |
| **database-documentation-gen** | Database plugin for database-documentation-gen | `ccpi install database-documentation-gen` |
| **database-health-monitor** | Database plugin for database-health-monitor | `ccpi install database-health-monitor` |
| **database-index-advisor** | Analyze query patterns and recommend optimal database indexe... | `ccpi install database-index-advisor` |
| **database-migration-manager** | Manage database migrations with version control, rollback ca... | `ccpi install database-migration-manager` |
| **database-partition-manager** | Database plugin for database-partition-manager | `ccpi install database-partition-manager` |
| **database-recovery-manager** | Database plugin for database-recovery-manager | `ccpi install database-recovery-manager` |
| **database-replication-manager** | Manage database replication, failover, and high availability... | `ccpi install database-replication-manager` |
| **database-schema-designer** | Design and visualize database schemas with normalization gui... | `ccpi install database-schema-designer` |
| **database-security-scanner** | Database plugin for database-security-scanner | `ccpi install database-security-scanner` |
| **database-sharding-manager** | Database plugin for database-sharding-manager | `ccpi install database-sharding-manager` |
| **database-transaction-monitor** | Database plugin for database-transaction-monitor | `ccpi install database-transaction-monitor` |
| **freshie-inventory-manager** | Unified command center for the freshie ecosystem inventory d... | `ccpi install freshie-inventory-manager` |
| **nosql-data-modeler** | Database plugin for nosql-data-modeler | `ccpi install nosql-data-modeler` |
| **orm-code-generator** | Generate ORM models from database schemas or create database... | `ccpi install orm-code-generator` |
| **query-performance-analyzer** | Analyze query performance with EXPLAIN plan interpretation, ... | `ccpi install query-performance-analyzer` |
| **sql-query-optimizer** | Analyze and optimize SQL queries for better performance, sug... | `ccpi install sql-query-optimizer` |
| **stored-procedure-generator** | Database plugin for stored-procedure-generator | `ccpi install stored-procedure-generator` |

## Crypto & Blockchain

**26 plugins**

| Plugin | Description | Install |
|--------|-------------|----------|
| **arbitrage-opportunity-finder** | Find and analyze arbitrage opportunities across exchanges an... | `ccpi install arbitrage-opportunity-finder` |
| **blockchain-explorer-cli** | Command-line blockchain explorer for transactions, addresses... | `ccpi install blockchain-explorer-cli` |
| **cross-chain-bridge-monitor** | Monitor cross-chain bridge activity, track transfers, analyz... | `ccpi install cross-chain-bridge-monitor` |
| **crypto-derivatives-tracker** | Track crypto futures, options, perpetual swaps with funding ... | `ccpi install crypto-derivatives-tracker` |
| **crypto-news-aggregator** | Aggregate and analyze crypto news from multiple sources with... | `ccpi install crypto-news-aggregator` |
| **crypto-portfolio-tracker** | Professional crypto portfolio tracking with real-time prices... | `ccpi install crypto-portfolio-tracker` |
| **crypto-signal-generator** | Generate trading signals from technical indicators and marke... | `ccpi install crypto-signal-generator` |
| **crypto-tax-calculator** | Calculate crypto taxes with FIFO/LIFO methods and generate t... | `ccpi install crypto-tax-calculator` |
| **defi-yield-optimizer** | Optimize DeFi yield farming strategies across protocols with... | `ccpi install defi-yield-optimizer` |
| **dex-aggregator-router** | Find optimal DEX routes for token swaps across multiple exch... | `ccpi install dex-aggregator-router` |
| **flash-loan-simulator** | Simulate and analyze flash loan strategies including arbitra... | `ccpi install flash-loan-simulator` |
| **gas-fee-optimizer** | Optimize transaction gas fees with timing and routing recomm... | `ccpi install gas-fee-optimizer` |
| **liquidity-pool-analyzer** | Analyze DeFi liquidity pools for impermanent loss, APY, and ... | `ccpi install liquidity-pool-analyzer` |
| **market-movers-scanner** | Scan for top market movers - gainers, losers, volume spikes,... | `ccpi install market-movers-scanner` |
| **market-price-tracker** | Real-time market price tracking with multi-exchange feeds an... | `ccpi install market-price-tracker` |
| **market-sentiment-analyzer** | Analyze market sentiment from social media, news, and on-cha... | `ccpi install market-sentiment-analyzer` |
| **mempool-analyzer** | Advanced mempool analysis for MEV opportunities, pending tra... | `ccpi install mempool-analyzer` |
| **nft-rarity-analyzer** | Analyze NFT rarity scores and valuations across collections | `ccpi install nft-rarity-analyzer` |
| **on-chain-analytics** | Analyze on-chain metrics including whale movements, network ... | `ccpi install on-chain-analytics` |
| **options-flow-analyzer** | Track institutional options flow, unusual activity, and smar... | `ccpi install options-flow-analyzer` |
| **staking-rewards-optimizer** | Optimize staking rewards across multiple protocols and chain... | `ccpi install staking-rewards-optimizer` |
| **token-launch-tracker** | Track new token launches, detect rugpulls, and analyze contr... | `ccpi install token-launch-tracker` |
| **trading-strategy-backtester** | Backtest trading strategies with historical data, performanc... | `ccpi install trading-strategy-backtester` |
| **wallet-portfolio-tracker** | Track crypto wallets across multiple chains with portfolio a... | `ccpi install wallet-portfolio-tracker` |
| **wallet-security-auditor** | Crypto wallet security auditor for reviewing wallet implemen... | `ccpi install wallet-security-auditor` |
| **whale-alert-monitor** | Monitor large crypto transactions and whale wallet movements... | `ccpi install whale-alert-monitor` |

## Business Tools

**22 plugins**

| Plugin | Description | Install |
|--------|-------------|----------|
| **brand-strategy-framework** | A 7-part brand strategy framework for building comprehensive... | `ccpi install brand-strategy-framework` |
| **excel-analyst-pro** | Professional financial modeling toolkit for Claude Code with... | `ccpi install excel-analyst-pro` |
| **executive-assistant-skills** | AI-powered executive assistant skills that fully replace a h... | `ccpi install executive-assistant-skills` |
| **general-legal-assistant** | AI-powered contract review, risk analysis, document generati... | `ccpi install general-legal-assistant` |
| **openbb-terminal** | Open-source investment research terminal integration - equit... | `ccpi install openbb-terminal` |
| **promptbook** | Opt-in Claude Code analytics. After setup consent, Promptboo... | `ccpi install promptbook` |
| **wondelai-blue-ocean-strategy** | Blue Ocean Strategy framework for creating uncontested marke... | `ccpi install wondelai-blue-ocean-strategy` |
| **wondelai-contagious** | Word-of-mouth and virality framework using the STEPPS model | `ccpi install wondelai-contagious` |
| **wondelai-cro-methodology** | Customer-centric conversion rate optimization methodology | `ccpi install wondelai-cro-methodology` |
| **wondelai-crossing-the-chasm** | Technology adoption and go-to-market strategy for mainstream... | `ccpi install wondelai-crossing-the-chasm` |
| **wondelai-drive-motivation** | Intrinsic motivation science framework (Autonomy, Mastery, P... | `ccpi install wondelai-drive-motivation` |
| **wondelai-hundred-million-offers** | Grand Slam Offer creation framework for irresistible pricing | `ccpi install wondelai-hundred-million-offers` |
| **wondelai-influence-psychology** | Persuasion science framework based on Cialdini's six princip... | `ccpi install wondelai-influence-psychology` |
| **wondelai-jobs-to-be-done** | Strategic product innovation framework using JTBD theory | `ccpi install wondelai-jobs-to-be-done` |
| **wondelai-made-to-stick** | Sticky messaging framework using the SUCCESs model | `ccpi install wondelai-made-to-stick` |
| **wondelai-negotiation** | Tactical negotiation framework based on Chris Voss's techniq... | `ccpi install wondelai-negotiation` |
| **wondelai-obviously-awesome** | Product positioning framework for competitive differentiatio... | `ccpi install wondelai-obviously-awesome` |
| **wondelai-one-page-marketing** | End-to-end marketing plan framework in a single page | `ccpi install wondelai-one-page-marketing` |
| **wondelai-predictable-revenue** | Outbound sales methodology for scalable B2B pipeline | `ccpi install wondelai-predictable-revenue` |
| **wondelai-scorecard-marketing** | Lead generation framework using quiz and assessment funnels | `ccpi install wondelai-scorecard-marketing` |
| **wondelai-storybrand-messaging** | StoryBrand messaging framework that positions customer as he... | `ccpi install wondelai-storybrand-messaging` |
| **wondelai-traction-eos** | Entrepreneurial Operating System for business execution | `ccpi install wondelai-traction-eos` |

## SaaS Packs

**107 plugins**

| Plugin | Description | Install |
|--------|-------------|----------|
| **abridge-pack** | Claude Code skill pack for Abridge (18 skills) | `ccpi install abridge-pack` |
| **adobe-pack** | Claude Code skill pack for Adobe (30 skills) | `ccpi install adobe-pack` |
| **alchemy-pack** | Claude Code skill pack for Alchemy (18 skills) | `ccpi install alchemy-pack` |
| **algolia-pack** | Claude Code skill pack for Algolia (24 skills) | `ccpi install algolia-pack` |
| **anima-pack** | Claude Code skill pack for Anima (18 skills) | `ccpi install anima-pack` |
| **anthropic-pack** | Claude Code skill pack for Anthropic (30 skills) | `ccpi install anthropic-pack` |
| **apify-pack** | Claude Code skill pack for Apify (18 skills) | `ccpi install apify-pack` |
| **apollo-pack** | Claude Code skill pack for Apollo.io sales intelligence plat... | `ccpi install apollo-pack` |
| **appfolio-pack** | Claude Code skill pack for AppFolio (18 skills) | `ccpi install appfolio-pack` |
| **apple-notes-pack** | Claude Code skill pack for Apple Notes (24 skills) | `ccpi install apple-notes-pack` |
| **assemblyai-pack** | Claude Code skill pack for AssemblyAI (18 skills) | `ccpi install assemblyai-pack` |
| **attio-pack** | Claude Code skill pack for Attio (18 skills) | `ccpi install attio-pack` |
| **bamboohr-pack** | Claude Code skill pack for BambooHR (18 skills) | `ccpi install bamboohr-pack` |
| **brightdata-pack** | Claude Code skill pack for Bright Data (18 skills) | `ccpi install brightdata-pack` |
| **canva-pack** | Claude Code skill pack for Canva (30 skills) | `ccpi install canva-pack` |
| **castai-pack** | Claude Code skill pack for Cast AI (18 skills) | `ccpi install castai-pack` |
| **clari-pack** | Claude Code skill pack for Clari (18 skills) | `ccpi install clari-pack` |
| **claude-pack** | Claude Code skill pack for building with the Claude API and ... | `ccpi install claude-pack` |
| **clay-pack** | Claude Code skill pack for Clay (30 skills) | `ccpi install clay-pack` |
| **clerk-pack** | Claude Code skill pack for Clerk authentication (24 skills) | `ccpi install clerk-pack` |
| **clickhouse-pack** | Claude Code skill pack for ClickHouse (24 skills) | `ccpi install clickhouse-pack` |
| **clickup-pack** | Claude Code skill pack for ClickUp (24 skills) | `ccpi install clickup-pack` |
| **coderabbit-pack** | Claude Code skill pack for CodeRabbit (24 skills) | `ccpi install coderabbit-pack` |
| **cohere-pack** | Claude Code skill pack for Cohere (24 skills) | `ccpi install cohere-pack` |
| **coreweave-pack** | Claude Code skill pack for CoreWeave (24 skills) | `ccpi install coreweave-pack` |
| **cursor-pack** | Flagship+ skill pack for Cursor IDE - 30 skills for AI code ... | `ccpi install cursor-pack` |
| **customerio-pack** | Claude Code skill pack for Customer.io (24 skills) | `ccpi install customerio-pack` |
| **databricks-pack** | Claude Code skill pack for Databricks (24 skills) | `ccpi install databricks-pack` |
| **deepgram-pack** | Claude Code skill pack for Deepgram (24 skills) | `ccpi install deepgram-pack` |
| **documenso-pack** | Claude Code skill pack for Documenso (24 skills) | `ccpi install documenso-pack` |
| **elevenlabs-pack** | Claude Code skill pack for ElevenLabs (18 skills) | `ccpi install elevenlabs-pack` |
| **evernote-pack** | Claude Code skill pack for Evernote (24 skills) | `ccpi install evernote-pack` |
| **exa-pack** | Claude Code skill pack for Exa (30 skills) | `ccpi install exa-pack` |
| **fathom-pack** | Claude Code skill pack for Fathom (18 skills) | `ccpi install fathom-pack` |
| **figma-pack** | Claude Code skill pack for Figma (30 skills) | `ccpi install figma-pack` |
| **finta-pack** | Claude Code skill pack for Finta (18 skills) | `ccpi install finta-pack` |
| **firecrawl-pack** | Claude Code skill pack for FireCrawl (30 skills) | `ccpi install firecrawl-pack` |
| **fireflies-pack** | Claude Code skill pack for Fireflies.ai (24 skills) | `ccpi install fireflies-pack` |
| **flexport-pack** | Claude Code skill pack for Flexport (24 skills) | `ccpi install flexport-pack` |
| **flyio-pack** | Claude Code skill pack for Fly.io (18 skills) | `ccpi install flyio-pack` |
| **fondo-pack** | Claude Code skill pack for Fondo (18 skills) | `ccpi install fondo-pack` |
| **framer-pack** | Claude Code skill pack for Framer (18 skills) | `ccpi install framer-pack` |
| **gamma-pack** | Claude Code skill pack for Gamma (24 skills) | `ccpi install gamma-pack` |
| **glean-pack** | Claude Code skill pack for Glean (24 skills) | `ccpi install glean-pack` |
| **grammarly-pack** | Claude Code skill pack for Grammarly (24 skills) | `ccpi install grammarly-pack` |
| **granola-pack** | Claude Code skill pack for Granola AI meeting notes (24 skil... | `ccpi install granola-pack` |
| **groq-pack** | Claude Code skill pack for Groq (24 skills) | `ccpi install groq-pack` |
| **guidewire-pack** | Claude Code skill pack for Guidewire InsuranceSuite (24 skil... | `ccpi install guidewire-pack` |
| **hex-pack** | Claude Code skill pack for Hex (18 skills) | `ccpi install hex-pack` |
| **hootsuite-pack** | Claude Code skill pack for Hootsuite (18 skills) | `ccpi install hootsuite-pack` |
| **hubspot-pack** | Claude Code skill pack for HubSpot (30 skills) | `ccpi install hubspot-pack` |
| **ideogram-pack** | Claude Code skill pack for Ideogram (24 skills) | `ccpi install ideogram-pack` |
| **instantly-pack** | Claude Code skill pack for Instantly (24 skills) | `ccpi install instantly-pack` |
| **intercom-pack** | Claude Code skill pack for Intercom (24 skills) | `ccpi install intercom-pack` |
| **juicebox-pack** | Claude Code skill pack for Juicebox (24 skills) | `ccpi install juicebox-pack` |
| **klaviyo-pack** | Claude Code skill pack for Klaviyo (24 skills) | `ccpi install klaviyo-pack` |
| **klingai-pack** | Kling AI skill pack - 30 skills for AI video generation, ima... | `ccpi install klingai-pack` |
| **langchain-pack** | Claude Code skill pack for LangChain (24 skills) | `ccpi install langchain-pack` |
| **langchain-py-pack** | Claude Code skill pack for LangChain 1.0 + LangGraph 1.0 (Py... | `ccpi install langchain-py-pack` |
| **langfuse-pack** | Claude Code skill pack for Langfuse LLM observability (24 sk... | `ccpi install langfuse-pack` |
| **lindy-pack** | Claude Code skill pack for Lindy AI (24 skills) | `ccpi install lindy-pack` |
| **linear-pack** | Claude Code skill pack for Linear (24 skills) | `ccpi install linear-pack` |
| **linktree-pack** | Claude Code skill pack for Linktree (18 skills) | `ccpi install linktree-pack` |
| **lokalise-pack** | Claude Code skill pack for Lokalise (24 skills) | `ccpi install lokalise-pack` |
| **lucidchart-pack** | Claude Code skill pack for Lucidchart (18 skills) | `ccpi install lucidchart-pack` |
| **maintainx-pack** | Claude Code skill pack for MaintainX CMMS (24 skills) | `ccpi install maintainx-pack` |
| **mindtickle-pack** | Claude Code skill pack for Mindtickle (18 skills) | `ccpi install mindtickle-pack` |
| **miro-pack** | Claude Code skill pack for Miro (24 skills) | `ccpi install miro-pack` |
| **mistral-pack** | Claude Code skill pack for Mistral AI (24 skills) | `ccpi install mistral-pack` |
| **navan-pack** | Claude Code skill pack for Navan (24 skills) | `ccpi install navan-pack` |
| **notion-pack** | Claude Code skill pack for Notion (30 skills) | `ccpi install notion-pack` |
| **obsidian-pack** | Claude Code skill pack for Obsidian plugin development and v... | `ccpi install obsidian-pack` |
| **onenote-pack** | Claude Code skill pack for OneNote (18 skills) | `ccpi install onenote-pack` |
| **openevidence-pack** | Claude Code skill pack for OpenEvidence medical AI (24 skill... | `ccpi install openevidence-pack` |
| **openrouter-pack** | Flagship+ skill pack for OpenRouter - 30 skills for multi-mo... | `ccpi install openrouter-pack` |
| **oraclecloud-pack** | Claude Code skill pack for Oracle Cloud (24 skills) | `ccpi install oraclecloud-pack` |
| **palantir-pack** | Claude Code skill pack for Palantir (24 skills) | `ccpi install palantir-pack` |
| **perplexity-pack** | Claude Code skill pack for Perplexity (30 skills) | `ccpi install perplexity-pack` |
| **persona-pack** | Claude Code skill pack for Persona (18 skills) | `ccpi install persona-pack` |
| **podium-pack** | Claude Code skill pack for Podium (18 skills) | `ccpi install podium-pack` |
| **posthog-pack** | Claude Code skill pack for PostHog (24 skills) | `ccpi install posthog-pack` |
| **procore-pack** | Claude Code skill pack for Procore (24 skills) | `ccpi install procore-pack` |
| **quicknode-pack** | Claude Code skill pack for QuickNode (18 skills) | `ccpi install quicknode-pack` |
| **ramp-pack** | Claude Code skill pack for Ramp (24 skills) | `ccpi install ramp-pack` |
| **remofirst-pack** | Claude Code skill pack for RemoFirst (12 skills) | `ccpi install remofirst-pack` |
| **replit-pack** | Claude Code skill pack for Replit (30 skills) | `ccpi install replit-pack` |
| **retellai-pack** | Claude Code skill pack for Retell AI (30 skills) | `ccpi install retellai-pack` |
| **runway-pack** | Claude Code skill pack for Runway (18 skills) | `ccpi install runway-pack` |
| **salesforce-pack** | Claude Code skill pack for Salesforce (30 skills) | `ccpi install salesforce-pack` |
| **salesloft-pack** | Claude Code skill pack for Salesloft (18 skills) | `ccpi install salesloft-pack` |
| **sentry-pack** | Claude Code skill pack for Sentry (30 skills) | `ccpi install sentry-pack` |
| **serpapi-pack** | Claude Code skill pack for SerpApi (18 skills) | `ccpi install serpapi-pack` |
| **shopify-pack** | Claude Code skill pack for Shopify (30 skills) | `ccpi install shopify-pack` |
| **snowflake-pack** | Claude Code skill pack for Snowflake data platform — snowfla... | `ccpi install snowflake-pack` |
| **speak-pack** | Claude Code skill pack for Speak AI Language Learning Platfo... | `ccpi install speak-pack` |
| **stackblitz-pack** | Claude Code skill pack for StackBlitz (18 skills) | `ccpi install stackblitz-pack` |
| **supabase-pack** | Claude Code skill pack for Supabase (30 skills) | `ccpi install supabase-pack` |
| **techsmith-pack** | Claude Code skill pack for TechSmith (18 skills) | `ccpi install techsmith-pack` |
| **together-pack** | Claude Code skill pack for Together AI (18 skills) | `ccpi install together-pack` |
| **twinmind-pack** | Claude Code skill pack for TwinMind (24 skills) | `ccpi install twinmind-pack` |
| **vastai-pack** | Claude Code skill pack for Vast.ai (24 skills) | `ccpi install vastai-pack` |
| **veeva-pack** | Claude Code skill pack for Veeva (24 skills) | `ccpi install veeva-pack` |
| **vercel-pack** | Claude Code skill pack for Vercel (30 skills) | `ccpi install vercel-pack` |
| **webflow-pack** | Claude Code skill pack for Webflow (24 skills) | `ccpi install webflow-pack` |
| **windsurf-pack** | Claude Code skill pack for Windsurf (30 skills) | `ccpi install windsurf-pack` |
| **wispr-pack** | Claude Code skill pack for Wispr (18 skills) | `ccpi install wispr-pack` |
| **workhuman-pack** | Claude Code skill pack for Workhuman (18 skills) | `ccpi install workhuman-pack` |

## Productivity

**22 plugins**

| Plugin | Description | Install |
|--------|-------------|----------|
| **000-jeremy-content-consistency-validator** | Read-only validator that generates comprehensive discrepancy... | `ccpi install 000-jeremy-content-consistency-validator` |
| **002-jeremy-yaml-master-agent** | Intelligent YAML validation, generation, and transformation ... | `ccpi install 002-jeremy-yaml-master-agent` |
| **003-jeremy-vertex-ai-media-master** | Comprehensive Google Vertex AI multimodal mastery for Jeremy... | `ccpi install 003-jeremy-vertex-ai-media-master` |
| **004-jeremy-google-cloud-agent-sdk** | Google Cloud Agent Development Kit (ADK) and Agent Starter P... | `ccpi install 004-jeremy-google-cloud-agent-sdk` |
| **agent-context-manager** | Automatically detects and loads AGENTS.md files to provide a... | `ccpi install agent-context-manager` |
| **ai-commit-gen** | AI-powered commit message generator - analyzes your git diff... | `ccpi install ai-commit-gen` |
| **box-cloud-filesystem** | Transparent cloud filesystem for AI agents using Box CLI (@b... | `ccpi install box-cloud-filesystem` |
| **claude-memory-kit** | 5 Claude Code skills for context management. Save, load, upd... | `ccpi install claude-memory-kit` |
| **claudebase** | Back up and restore your entire Claude Code environment to a... | `ccpi install claudebase` |
| **cli-power-skills** | Agentic CLI tool skills for Claude Code — 7 domain-grouped s... | `ccpi install cli-power-skills` |
| **hyperfocus** | ADHD-friendly output formatting for Claude Code. Restructure... | `ccpi install hyperfocus` |
| **navigating-github** | Adaptive GitHub companion for all skill levels. AI-driven as... | `ccpi install navigating-github` |
| **neurodivergent-visual-org** | Create ADHD-friendly visual organizational tools (Mermaid di... | `ccpi install neurodivergent-visual-org` |
| **overnight-dev** | Run Claude autonomously for 6-8 hours overnight using Git ho... | `ccpi install overnight-dev` |
| **plane** | Plane is a team behavior observatory — synthesize Plane API ... | `ccpi install plane` |
| **pm-ai-partner** | 12 PM-specific agent skills, 6 workflow commands, 3 automati... | `ccpi install pm-ai-partner` |
| **prettier-markdown-hook** | Automatically formats markdown files with prettier on Stop h... | `ccpi install prettier-markdown-hook` |
| **travel-assistant** | Intelligent travel assistant with real-time weather, currenc... | `ccpi install travel-assistant` |
| **vibe-guide** | Non-technical progress summaries for Claude Code work (hides... | `ccpi install vibe-guide` |
| **wondelai-design-sprint** | Google Ventures Design Sprint methodology for rapid prototyp... | `ccpi install wondelai-design-sprint` |
| **wondelai-lean-startup** | Lean Startup methodology for validated learning and MVPs | `ccpi install wondelai-lean-startup` |
| **youtube-strategy** | Complete YouTube content production workflow: research compe... | `ccpi install youtube-strategy` |

## MCP

**10 plugins**

| Plugin | Description | Install |
|--------|-------------|----------|
| **ai-experiment-logger** | Track and analyze AI experiments with a web dashboard and MC... | `ccpi install ai-experiment-logger` |
| **conversational-api-debugger** | Debug REST API failures using OpenAPI specs and HTTP logs. A... | `ccpi install conversational-api-debugger` |
| **design-to-code** | Convert Figma designs and screenshots into production-ready ... | `ccpi install design-to-code` |
| **domain-memory-agent** | Knowledge base with semantic search, document storage, and a... | `ccpi install domain-memory-agent` |
| **lumera-agent-memory** | Durable agent memory with Cascade object storage, client-sid... | `ccpi install lumera-agent-memory` |
| **pr-to-spec** | The flight envelope for agentic coding. Convert PRs and loca... | `ccpi install pr-to-spec` |
| **project-health-auditor** | Analyze local repos for code health, complexity, test covera... | `ccpi install project-health-auditor` |
| **slack-channel** | Two-way Slack channel for Claude Code — chat from Slack DMs ... | `ccpi install slack-channel` |
| **workflow-orchestrator** | Orchestrate complex workflows with DAG-based execution, para... | `ccpi install workflow-orchestrator` |
| **x-bug-triage-plugin** | Closed-loop bug triage: X complaints → clusters → repo evide... | `ccpi install x-bug-triage-plugin` |

## Design

**7 plugins**

| Plugin | Description | Install |
|--------|-------------|----------|
| **wondelai-design-everyday-things** | Fundamental design principles for intuitive interfaces | `ccpi install wondelai-design-everyday-things` |
| **wondelai-hooked-ux** | Hook Model framework for building habit-forming products | `ccpi install wondelai-hooked-ux` |
| **wondelai-ios-hig-design** | Native iOS app design following Apple Human Interface Guidel... | `ccpi install wondelai-ios-hig-design` |
| **wondelai-refactoring-ui** | Practical UI design system for professional interfaces | `ccpi install wondelai-refactoring-ui` |
| **wondelai-top-design** | Award-winning web design framework for premium experiences | `ccpi install wondelai-top-design` |
| **wondelai-ux-heuristics** | Usability heuristics and principles for UX audits | `ccpi install wondelai-ux-heuristics` |
| **wondelai-web-typography** | Web typography framework for readable, beautiful type | `ccpi install wondelai-web-typography` |

## Skill Enhancers

**7 plugins**

| Plugin | Description | Install |
|--------|-------------|----------|
| **calendar-to-workflow** | Enhances calendar Skills by automating meeting prep, standup... | `ccpi install calendar-to-workflow` |
| **file-to-code** | Enhances file reading Skills by generating production-ready ... | `ccpi install file-to-code` |
| **research-to-deploy** | Enhances web_search Skill by researching best practices and ... | `ccpi install research-to-deploy` |
| **search-to-slack** | Enhances web_search Skill by posting formatted research dige... | `ccpi install search-to-slack` |
| **skill-creator** | Create and validate production-grade agent skills with 100-p... | `ccpi install skill-creator` |
| **validate-plugin** | Validates Claude Code plugin structure against official Anth... | `ccpi install validate-plugin` |
| **web-to-github-issue** | Enhances web_search Skill by automatically creating GitHub i... | `ccpi install web-to-github-issue` |

## Community

**12 plugins**

| Plugin | Description | Install |
|--------|-------------|----------|
| **b12-claude-plugin** | B12 Website Generator plugin allows you to create a professi... | `ccpi install b12-claude-plugin` |
| **boycott-filter** | Personal boycott list managed conversationally by your AI ag... | `ccpi install boycott-filter` |
| **claude-never-forgets** | Persistent memory across sessions. Learns preferences, conve... | `ccpi install claude-never-forgets` |
| **claude-reflect** | Self-learning system for Claude Code that captures correctio... | `ccpi install claude-reflect` |
| **fairdb-ops-manager** | Comprehensive operations manager for FairDB managed PostgreS... | `ccpi install fairdb-ops-manager` |
| **framecraft** | Generate polished demo videos from a single prompt. Orchestr... | `ccpi install framecraft` |
| **gastown** | Multi-agent orchestrator for Claude Code. Track work with co... | `ccpi install gastown` |
| **geepers** | Multi-agent orchestration system with MCP tools and Claude C... | `ccpi install geepers` |
| **jeremy-firebase** | Firebase platform expert for Firestore, Auth, Functions, and... | `ccpi install jeremy-firebase` |
| **jeremy-firestore** | Firestore database specialist for schema design, queries, an... | `ccpi install jeremy-firestore` |
| **sprint** | Autonomous multi-agent development framework with spec-drive... | `ccpi install sprint` |
| **zai-cli** | Z.AI vision, search, reader, and GitHub exploration via CLI ... | `ccpi install zai-cli` |

## Examples

**5 plugins**

| Plugin | Description | Install |
|--------|-------------|----------|
| **formatter** | Comprehensive code formatting plugin with Prettier integrati... | `ccpi install formatter` |
| **hello-world** | Simple example plugin demonstrating basic slash commands | `ccpi install hello-world` |
| **jeremy-plugin-tool** | Ultimate plugin management toolkit with 4 auto-invoked Skill... | `ccpi install jeremy-plugin-tool` |
| **pi-pathfinder** | PI Pathfinder - Finds the path through 229 plugins. Automati... | `ccpi install pi-pathfinder` |
| **security-agent** | Specialized security review subagent | `ccpi install security-agent` |

