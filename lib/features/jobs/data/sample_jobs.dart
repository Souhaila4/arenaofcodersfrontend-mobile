import 'package:arena/features/jobs/models/job_posting.dart';

/// Static listings for UX until backend job feeds are wired.
const List<JobPosting> kSampleJobs = [
  JobPosting(
    id: 'sample-1',
    title: 'Senior Flutter Engineer',
    company: 'TechNova Labs',
    location: 'Remote · EU',
    description:
        'We need an engineer to ship polished cross-platform apps with '
        'clean architecture (Riverpod/Bloc), Dio/REST integration, and CI/CD. '
        'You will collaborate with design on animations and accessibility, '
        'profile performance, and mentor juniors. Experience with streams, '
        'testing (widget & integration), and App Store / Play releases required.',
  ),
  JobPosting(
    id: 'sample-2',
    title: 'Backend Engineer (NestJS)',
    company: 'Arena Analytics',
    location: 'Hybrid · Tunis',
    description:
        'Build APIs on NestJS + Prisma + MongoDB: auth, rate limits, webhooks, '
        'and integrations with third-party AI providers. Strong TypeScript, '
        'OpenAPI/Swagger, and production debugging expected. Bonus: Redis, '
        'queues, observability.',
  ),
  JobPosting(
    id: 'sample-3',
    title: 'ML Engineer — NLP',
    company: 'DataForge',
    location: 'Remote',
    description:
        'Fine-tune and deploy LLM workflows for customer support: RAG pipelines, '
        'evaluation, guardrails, and latency-aware inference. Python, PyTorch '
        'or similar, plus experience shipping models behind REST APIs.',
  ),
];
