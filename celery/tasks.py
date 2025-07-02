from psycopg2.extras import RealDictCursor
import psycopg2
from celery import Celery
import os
import docker
import shutil


app = Celery(
    'tasks',
    broker=os.environ.get('CELERY_BROKER_URL', 'redis://redis:6390/0'),
    backend=os.environ.get('CELERY_RESULT_BACKEND', 'redis://redis:6390/0'),
)
IMAGE_NAME = os.environ.get('IMAGE_NAME', 'my_docker_image:2')
ABSOLUTE_PATH = os.environ.get(
    "ABSOLUTE_PATH", "C:/Users/CD CENTER/Desktop/database project/Database")
client = docker.from_env()


def get_pg_connection():
    return psycopg2.connect(
        host=os.environ.get('POSTGRES_HOST', 'localhost'),
        port=os.environ.get('POSTGRES_PORT', '5432'),
        dbname=os.environ.get('POSTGRES_DB', 'mydb'),
        user=os.environ.get('POSTGRES_USER', 'myuser'),
        password=os.environ.get('POSTGRES_PASSWORD', 'mypassword'),
        cursor_factory=RealDictCursor
    )


conn = get_pg_connection()


def normalize_content(file_path):
    with open(file_path, 'r') as f:
        content = f.read()
        # Remove all whitespace: spaces, tabs, newlines
        return ''.join(content.split())


def compare_files(file1, file2):
    content1 = normalize_content(file1)
    content2 = normalize_content(file2)

    if content1 == content2:
        print("✅ Files are the same (ignoring whitespace).")
        return True
    else:
        print("❌ Files differ (ignoring whitespace).")
        return False


@app.task(name='tasks.start')
def start_container(code_id):
    try:
        cur = conn.cursor()
        cur.execute("""UPDATE Code SET accepted=False, status=%s WHERE code_id=%s;""",
                    ("pending", code_id))
        conn.commit()
        cur = conn.cursor()
        cur.execute("""select * from Code where code_id=%s;""",
                    (code_id,))

        row = cur.fetchone()
        username = row['user_id']
        path = row['path']

        print(
            f"Starting container for code_id: {code_id} and username: {username}")
        test_cases = cur.execute("""select * from TestCase test JOIN Code code ON code.problem_id=test.problem_id where code.code_id=%s;""",
                                 (code_id,))

        test_cases = cur.fetchall()
        if not test_cases:
            return f"No test cases found for code_id: {code_id}"
        print(f"Test cases: {test_cases}")
        if (os.path.exists(f'/app/shared/spec/{username}')):
            shutil.rmtree(f'/app/shared/spec/{username}')
        os.mkdir(f'/app/shared/spec/{username}')

        os.mkdir(f'/app/shared/spec/{username}/code')
        os.mkdir(f'/app/shared/spec/{username}/inputs')
        os.mkdir(f'/app/shared/spec/{username}/outputs')

        for test_case in test_cases:
            input_file = test_case['input_file']
            print(os.listdir(f'/app/shared/uploads/'))
            shutil.copy(f'/app/shared/uploads/{input_file}',
                        f'/app/shared/spec/{username}/inputs/{input_file.split("/")[-1]}')

        shutil.copy(f'/app/shared/uploads/{path}',
                    f'/app/shared/spec/{username}/code/code.cpp')

        container = client.containers.run(
            image=IMAGE_NAME,
            volumes={
                f'{ABSOLUTE_PATH}/spec/{username}': {
                    'bind': f'/app/shared',
                    'mode': 'rw'
                },
            },
            detach=True,
            remove=True,

        )
        print(f"Container started with ID: {container.id}")
        try:
            result = container.wait(timeout=5)
            print(f"Container result: {result}")
        except docker.errors.APIError:
            cur.execute("""UPDATE Code SET accepted=False, status=%s WHERE code_id=%s;""",
                        ("time limit exceeded", code_id))
            return f"Container timed out: {container.id}"
        else:
            container.reload()
            if container.status != 'exited':
                cur.execute("""UPDATE Code SET accepted=False, status=%s WHERE code_id=%s;""",
                            ("runtime error", code_id))
                print(
                    f"Container exited with status code: {result.get('StatusCode', 1)}")

            elif result.get("StatusCode", 1) != 0:
                cur.execute("""UPDATE Code SET accepted=False, status=%s WHERE code_id=%s;""",
                            ("runtime error", code_id))
                print(
                    f"Container exited with status code: {result.get('StatusCode', 1)}")
        print(
            f"Container exited with status code: {result.get('StatusCode', 1)}")
        print("Container execution completed")
        print("Comparing outputs")
        identical = True
        for test_case in test_cases:
            input_file = f"/app/shared/spec/{username}/inputs/{test_case['input_file'].split('/')[-1]}"
            output_file = f"/app/shared/spec/{username}/outputs/{test_case['input_file'].split('/')[-1]}"
            true_output_file = f"/app/shared/uploads/{test_case['output_file']}"
            print(f"Comparing {output_file} with {true_output_file}")
            if (not compare_files(output_file, true_output_file)):
                print(f"Outputs are not identical for {input_file}")
                identical = False
                break

        if (identical):
            print("All outputs are identical")
            cur.execute("""UPDATE Code SET accepted=True, status=%s WHERE code_id=%s;""",
                        ("accepted", code_id))
        else:
            print("Outputs are not identical")
            cur.execute("""UPDATE Code SET accepted=False, status=%s WHERE code_id=%s;""",
                        ("wrong answer", code_id))

        conn.commit()
        cur.close()
        return f"{container.id}"
    except docker.errors.APIError as e:
        return f"Error starting container: {str(e)}"
