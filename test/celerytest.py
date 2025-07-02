from celery import Celery

app = Celery(
    'client',
    broker='redis://localhost:6391/0',
    backend='redis://localhost:6391/0'
)
# initial test
result = app.send_task('tasks.start', args=[1])
print("Result:", result.get(timeout=10))
