# DevOps & SRE with Kubernetes and GitOps - Course Materials

## Course Overview

This comprehensive course teaches production-grade DevOps and SRE practices through hands-on labs using real-world tools and workflows. Students will build, deploy, and operate a complete microservices platform using Kubernetes, FluxCD, and modern observability tools.

**Total Duration:** 35-45 hours
**Level:** Intermediate to Advanced
**Prerequisites:**
- Basic Linux command line knowledge
- Understanding of containers (Docker basics)
- Git fundamentals
- Basic programming knowledge (any language)
- Local machine with Docker Desktop installed

## What You'll Build

By the end of this course, you will have built and operated:

- ✅ Production-ready Kubernetes cluster (local KIND + concepts for cloud)
- ✅ Fully automated CI/CD pipeline with GitHub Actions
- ✅ GitOps-driven deployments with FluxCD
- ✅ Complete observability stack (Prometheus, Grafana, Loki, tracing)
- ✅ Secure secrets management
- ✅ Automated image scanning and signing
- ✅ Advanced deployment strategies (canary, blue/green)
- ✅ Disaster recovery procedures

## Course Structure

### Part 1: Foundations (Chapters 1-4)
Build your understanding of core concepts and set up your infrastructure foundation.

- **Chapter 1:** Introduction to DevOps & SRE
- **Chapter 2:** Containerization Best Practices
- **Chapter 3:** Kubernetes Fundamentals
- **Chapter 4:** Infrastructure as Code with Terraform

### Part 2: GitOps & CI/CD (Chapters 5-7)
Learn to automate deployments and manage configurations declaratively.

- **Chapter 5:** GitOps with FluxCD
- **Chapter 6:** CI/CD Pipeline Design
- **Chapter 7:** Configuration Management with Kustomize

### Part 3: Observability (Chapters 8-11)
Master the three pillars of observability: metrics, logs, and traces.

- **Chapter 8:** Observability - Metrics with Prometheus & Grafana
- **Chapter 9:** Observability - Logging with Loki
- **Chapter 10:** Observability - Distributed Tracing
- **Chapter 11:** Alerting & Incident Response

### Part 4: Security & Quality (Chapters 12-13)
Implement security best practices and quality gates.

- **Chapter 12:** Security Best Practices
- **Chapter 13:** Testing & Quality Gates

### Part 5: Advanced Topics (Chapters 14-16)
Learn advanced deployment strategies and production operations.

- **Chapter 14:** Advanced Deployment Strategies
- **Chapter 15:** Disaster Recovery & Backup
- **Chapter 16:** Production Readiness & Best Practices

### Part 6: Capstone Project (Chapter 17)
Put everything together in a comprehensive final project.

- **Chapter 17:** Final Project - Complete Production Deployment

## Chapter Details

Each chapter includes:

- 📖 **Lecture Notes** - Theoretical concepts and best practices
- 🎯 **Learning Objectives** - What you'll be able to do after completing the chapter
- 🛠️ **Hands-on Labs** - Step-by-step practical exercises
- 📝 **Lab Solutions** - Reference implementations
- ✅ **Knowledge Checks** - Quick quizzes to verify understanding
- 🔗 **Additional Resources** - Links to documentation and further reading

## How to Use This Course

### For Self-Paced Learning:

1. Start with Chapter 1 and progress sequentially
2. Complete all labs before moving to the next chapter
3. Use the knowledge checks to verify your understanding
4. Refer to the main repository README.md for setup instructions

### For Instructors:

- Each chapter is designed for 2-4 hours of instruction + labs
- Lab solutions are provided separately
- Demo scripts are available in `/scripts/demos/`
- Slide decks can reference the markdown content directly

## Repository Structure

```
docs/course/
├── README.md (this file)
├── chapter-01-introduction/
│   ├── README.md              # Lecture notes
│   ├── lab.md                 # Lab instructions
│   ├── lab-solution.md        # Lab solution
│   └── quiz.md                # Knowledge check
├── chapter-02-containerization/
│   ├── README.md
│   ├── lab-01-multistage.md
│   ├── lab-02-security.md
│   └── ...
└── ...
```

## Learning Path Recommendations

### For DevOps Engineers:
Focus on chapters 1-7, 12-16 (skip or skim observability deep-dives if already familiar)

### For SRE Practitioners:
Focus on chapters 3-5, 8-11, 14-16 (emphasize observability and reliability)

### For Platform Engineers:
Complete all chapters with extra attention to chapters 4-7, 12-13 (automation and security)

### For Developers:
Focus on chapters 1-3, 6-7, 8-9 (practical deployment and debugging skills)

## Support & Resources

- **Main Repository:** [github.com/ldbl/sre](https://github.com/ldbl/sre)
- **Issues & Questions:** Use GitHub Issues
- **Community:** Join our Discord server (link TBD)
- **Updates:** Watch the repository for course updates

## License

This course material is provided under the MIT License. See LICENSE file for details.

---

Ready to start? Head to [Chapter 1: Introduction to DevOps & SRE](./chapter-01-introduction/README.md)
