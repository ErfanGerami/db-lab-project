import logging
from rest_framework.views import APIView
from helper import MyListView, select, execute, generate_jwt_token
from .serializers import *
from rest_framework.response import Response
from rest_framework import status
from .mixins import AuthorizationMixin
from datetime import datetime
import os
import json
from uuid import uuid4
from django.core.files.storage import default_storage
from django.core.files.base import ContentFile
from django.db import transaction
from celery import Celery
from .permisions import *
app = Celery(
    'client',
    broker=settings.BROKER,
    backend=settings.BACKEND
)
# initial test

# Get logger instance
logger = logging.getLogger(__name__)


def can_access_problem(problem_id, username):
    # Check if the user is an admin for the contest
    admin_check = select(
        "SELECT EXISTS(SELECT 1 FROM admin_contest WHERE contest_id = (SELECT contest_id FROM Problem WHERE problem_id = %s) AND user_id = %s)",
        [problem_id, username]
    )
    if admin_check[0]['exists']:
        return True

    public_check = select(
        "SELECT public_private FROM Problem WHERE problem_id = %s and (select end_time from Contest where contest_id = (SELECT contest_id FROM Problem WHERE problem_id = %s)) > now()",
        [problem_id, problem_id]
    )
    if (len(public_check) == 0):
        return False
    if public_check[0]['public_private']:
        return True

    enrollment_check = select(
        "SELECT EXISTS(SELECT 1 FROM contest_user WHERE contest_id = (SELECT contest_id FROM Problem WHERE problem_id = %s) AND user_id = %s)",
        [problem_id, username]
    )

    return enrollment_check[0]['exists']


class GetProblems(AuthorizationMixin, MyListView):
    serializer = ProblemSerializer

    def get_query_set(self, request):
        rating_from = request.GET.get('rating_from', 0)
        rating_to = request.GET.get('rating_to', 10000)
        tags = request.GET.get('tags', None)
        query = """
            select distinct(p.name),p.problem_id,p.rating from
            Problem p JOIN Tag_Problem tp  ON p.problem_id=tp.problem_id
            JOIN Tag t ON t.name=tp.tag_id
            where rating > %s and rating < %s
            
            """
        if (tags):

            primary = select(query+" and t.name in (%s)",
                             (rating_from, rating_to, tags))
        else:
            primary = select(query, (rating_from, rating_to))
        main = []
        for i in primary:
            if (can_access_problem(i["problem_id"], request.COOKIES["username"])):
                main.append(i)
        return main


class GetContests(AuthorizationMixin, MyListView):
    serializer = ContestSerializer

    def get_query_set(self, request):
        return select("""select Contest.contest_id ,name ,start_time , end_time ,exists(select 1 from admin_contest where contest_id=Contest.contest_id and user_id = %s) as is_admin,exists(select 1 from contest_user where contest_user.contest_id = Contest.contest_id and contest_user.user_id = %s) as enrolled
        , case when  end_time<%s then 'ended' when start_time>%s then  'upcoming' else 'ongoing' end as status
        from Contest where start_time > now() or  exists(select 1 from admin_contest where contest_id=Contest.contest_id and user_id = %s) or exists(select 1 from contest_user where contest_user.contest_id = Contest.contest_id and contest_user.user_id = %s)

        order by is_admin,start_time,enrolled

        """, [request.COOKIES["username"], request.COOKIES["username"], datetime.now(), datetime.now(), request.COOKIES["username"], request.COOKIES["username"]])


class EnrollContest(AuthorizationMixin, APIView):
    def post(self, request):
        data = request.data
        contest_id = data.get("contest_id")
        if (not contest_id):
            return Response({"error": "contest_id is required"}, status=status.HTTP_400_BAD_REQUEST)
        print(request.COOKIES["username"])
        row = select(
            "select * from Contest where contest_id=%s ", [contest_id])
        if (len(row) == 0):
            return Response({"error": "no such contest"}, status=status.HTTP_400_BAD_REQUEST)
        print(row[0]['start_time'])
        if (row[0]['start_time'] < datetime.now()):
            return Response({"error": "contest already started"}, status=status.HTTP_400_BAD_REQUEST)

        execute("insert into contest_user (contest_id,user_id) values(%s,%s)",
                [contest_id, request.COOKIES["username"]], False)

        return Response({'message': 'success'}, status=200)


class GetTags(MyListView):
    serializer = TagSerializer
    query_set = "select name from Tag"


class Register(APIView):
    def post(self, request):

        data = request.data
        username = data.get("username")
        password = data.get("password")
        if (not username or not password):
            return Response({"error": "username and password are required"}, status=status.HTTP_400_BAD_REQUEST)
        hashed_pass = hash_pass(password)
        row = select(
            "select * from \"User\"  where username=%s ", [username])
        if (len(row) != 0):
            return Response({"error": "user already exists"}, status=status.HTTP_400_BAD_REQUEST)
        execute("insert into  \"User\" (username,password) values(%s,%s)",
                [data["username"], hashed_pass], False)

        return Response({'token': generate_jwt_token(username, hashed_pass)}, status=200)


class Login(APIView):
    def post(self, request):
        data = request.data
        username = data.get("username")
        password = data.get("password")
        if (not username or not password):
            return Response({"error": "username and password are required"}, status=status.HTTP_400_BAD_REQUEST)
        hashed_pass = hash_pass(password)
        row = select(
            "select * from \"User\" where password=%s  and username=%s ", [(hashed_pass), username])

        if (len(row) != 1):
            return Response({"error": "no such user"}, status=status.HTTP_400_BAD_REQUEST)

        return Response({'token': generate_jwt_token(username, hashed_pass)}, status=200)


class GetProblemSpecific(AuthorizationMixin, APIView):

    def get(self, request, problem_id):
        if (not can_access_problem(problem_id, request.COOKIES["username"])):
            return Response({"error": "doesnt have access"}, status=status.HTTP_400_BAD_REQUEST)

        row = select(
            "select * from Problem where problem_id=%s ", [problem_id])
        if (len(row) == 0):
            return Response({"error": "no such problem"}, status=status.HTTP_400_BAD_REQUEST)
        return Response({'problem': ProblemSpecificSerializer(row[0]).data}, status=200)


class GetToturial(AuthorizationMixin, APIView):

    def get(self, request, problem_id):
        row = select(
            "select problem_id,text,file from Toturial where problem_id=%s ", [problem_id])
        public_check = select(
            "SELECT (public_private or %s in (select user_id from Contest_user cu where cu.contest_id=contest_id)) as public_private FROM Problem WHERE problem_id = %s and (SELECT end_time from Contest where contest_id = (SELECT contest_id FROM Problem WHERE problem_id = %s)) > now()",
            [request.COOKIES["username"], problem_id, problem_id]
        )
        if (len(public_check) == 0):
            return Response({"error": "no such problem"}, status=status.HTTP_400_BAD_REQUEST)
        if public_check[0]['public_private']:
            return Response({"error": "no such problem"}, status=status.HTTP_400_BAD_REQUEST)

        if (len(row) == 0):
            return Response({"error": "no such problem"}, status=status.HTTP_400_BAD_REQUEST)

        print(ToturialSerializer(row[0]).data)
        return Response({'problem': ToturialSerializer(row[0]).data}, status=200)


class CreateContest(AuthorizationMixin, APIView):
    def post(self, request):
        data = request.data
        name = data.get("name")
        start_time = data.get("start_time")
        end_time = data.get("end_time")
        if (not name or not start_time or not end_time):
            return Response({"error": "name, start_time and end_time are required"}, status=status.HTTP_400_BAD_REQUEST)
        try:
            execute("insert into Contest (name,start_time,end_time) values(%s,%s,%s)",
                    [name, start_time, end_time], False)
            contest_id = select(
                "select contest_id from Contest where name=%s", [name])[0]["contest_id"]
            execute("insert into admin_contest (contest_id,user_id) values(%s,%s)",
                    [contest_id, request.COOKIES["username"]], False)
        except Exception as e:
            print(e)
            return Response({"error": "invalid time or name"}, status=status.HTTP_400_BAD_REQUEST)
        return Response({"message": "success", "contest_id": contest_id}, status=200)


class GetContestSpecific(AuthorizationMixin, MyListView):

    def get(self, request, contest_id):
        is_admin_in_the_contest = select("select exists(select * from admin_contest ac where ac.contest_id = %s and ac.user_id = %s) as is_admin", [
            contest_id, request.COOKIES["username"]])[0]["is_admin"]
        contest_started = select("select exists(select * from Contest where Contest.contest_id = %s and Contest.start_time < now()) as started", [
            contest_id])[0]["started"]
        if not (is_admin_in_the_contest or contest_started):
            return Response({"error": "doesnt have access"}, status=status.HTTP_400_BAD_REQUEST)

        row = select(
            "select * from Contest where contest_id=%s ", [contest_id])
        if (len(row) == 0):
            return Response({"error": "no such contest"}, status=status.HTTP_400_BAD_REQUEST)
        return Response({'contest': ContestSpecificSerializer(row[0]).data}, status=200)


class CreateProblem(AuthorizationMixin, APIView):
    def post(self, request):
        data = request.data
        print(data)

        # Extract basic problem info
        name = data.get("name")
        text = data.get("text")
        rating = data.get("rating")
        # Default to empty list if not provided
        tags = json.loads(data.get("tags", "[]"))
        contest_id = data.get("contest_id")
        public = data.get("public", False)  # Default to False if not provided
        tutorial_text = data.get("tutorial_text", "")

        # Validate required fields
        if not name or not text or not rating:
            return Response({"error": "name, text and rating are required"}, status=status.HTTP_400_BAD_REQUEST)

        try:
            # Create problem
            with transaction.atomic():

                execute("INSERT INTO Problem (name, public_private, contest_id, text, rating) VALUES (%s, %s, %s, %s, %s)",
                        [name, public, contest_id, text, rating], False)

                problem_id = select(
                    "SELECT problem_id FROM Problem WHERE name=%s AND contest_id=%s",
                    [name, contest_id]
                )[0]["problem_id"]

                # Handle tags
                if tags:
                    for tag in tags:
                        execute("INSERT INTO Tag_Problem (tag_id, problem_id) VALUES (%s, %s)",
                                [tag, problem_id], False)

                # Handle tutorial file
                tutorial_file_path = None
                if "tutorial_file" in request.FILES:
                    uploaded_file = request.FILES["tutorial_file"]
                    ext = os.path.splitext(uploaded_file.name)[1]
                    unique_filename = f"{uuid4().hex}{ext}"
                    relative_path = f"uploads/tutorials/{unique_filename}"
                    saved_file_path = default_storage.save(
                        relative_path, ContentFile(uploaded_file.read()))
                    tutorial_file_path = relative_path

                # Create tutorial
                execute("INSERT INTO Toturial (problem_id, text, file) VALUES (%s, %s, %s)",
                        [problem_id, tutorial_text, tutorial_file_path], False)

                # Handle test cases
                test_case_counter = 0
                while f"test_case_input_{test_case_counter}" in request.FILES:
                    input_file = request.FILES[f"test_case_input_{test_case_counter}"]
                    output_file = request.FILES[f"test_case_output_{test_case_counter}"]

                    # Save input file
                    input_ext = os.path.splitext(input_file.name)[1]
                    input_filename = f"{uuid4().hex}{input_ext}"
                    input_path = f"test_cases/{input_filename}"
                    default_storage.save(
                        input_path, ContentFile(input_file.read()))

                    # Save output file
                    output_ext = os.path.splitext(output_file.name)[1]
                    output_filename = f"{uuid4().hex}{output_ext}"
                    output_path = f"test_cases/{output_filename}"
                    default_storage.save(
                        output_path, ContentFile(output_file.read()))

                    # Store test case in database
                    execute("""
                            INSERT INTO TestCase (problem_id, input_file, output_file)
                            VALUES (%s, %s, %s)
                        """, [problem_id, input_path, output_path], False)

                    test_case_counter += 1

                if test_case_counter == 0:
                    return Response({"error": "At least one test case is required"},
                                    status=status.HTTP_400_BAD_REQUEST)

            return Response({
                "message": "success",
                "problem_id": problem_id,
                "test_cases_added": test_case_counter
            }, status=status.HTTP_201_CREATED)

        except Exception as e:
            print(e)
            return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)

    def delete(self, request):
        data = request.data
        problem_id = data.get("problem_id", 100)
        if (not problem_id):
            return Response({"error": "problem_id is required"}, status=status.HTTP_400_BAD_REQUEST)
        print(2)
        row = select(
            "select * from Problem where problem_id=%s ", [problem_id])
        if (len(row) == 0):
            return Response({"error": "no such problem"}, status=status.HTTP_400_BAD_REQUEST)
        print(3)
        execute("delete from Problem where problem_id=%s", [problem_id], False)

        return Response({'message': 'success'}, status=200)


class AddAdmin(AuthorizationMixin, APIView):
    permission_classes = [IsAdminOfContest]

    def post(self, request):
        data = request.data
        contest_id = data.get("contest_id")
        username = data.get("username")
        if (not contest_id or not username):
            return Response({"error": "contest_id and username are required"}, status=status.HTTP_400_BAD_REQUEST)
        row = select(
            "select * from Contest where contest_id=%s ", [contest_id])
        if (len(row) == 0):
            return Response({"error": "no such contest"}, status=status.HTTP_400_BAD_REQUEST)
        if (len(select("select * from \"User\" where username=%s ", [username])) == 0):
            return Response({"error": "no such user"}, status=status.HTTP_400_BAD_REQUEST)
        execute("insert into admin_contest (contest_id,user_id) values(%s,%s)",
                [contest_id, username], False)

        return Response({'message': 'success'}, status=200)


class GetAdmins(AuthorizationMixin, APIView):
    permission_classes = [HasAccessToContest]

    def get(self, request, contest_id):
        row = select(
            "select * from Contest where contest_id=%s ", [contest_id])
        if (len(row) == 0):
            return Response({"error": "no such contest"}, status=status.HTTP_400_BAD_REQUEST)
        admins = select(
            "select user_id from admin_contest where contest_id=%s ", [contest_id])

        return Response({"admins": [{"user_id": admin['user_id']} for admin in admins]}, status=200)


class GetScoreBoard(AuthorizationMixin, APIView):

    def get(self, request, contest_id):
        row = select(
            "select * from Contest where contest_id=%s ", [contest_id])
        if (len(row) == 0):
            return Response({"error": "no such contest"}, status=status.HTTP_400_BAD_REQUEST)
        score_board = select(
            """ SELECT
                username,
                solved_count,
                total_elapsed_seconds,
                RANK() OVER (
                    ORDER BY solved_count DESC, total_elapsed_seconds ASC
                ) AS rank
            FROM (
                SELECT
                    u.username,
                    COUNT(co.code_id) AS solved_count,
                    COALESCE(SUM(EXTRACT(EPOCH FROM (co.submission_time - con.start_time)))::BIGINT, 0) AS total_elapsed_seconds
                FROM "User" u
                JOIN Contest_User us
                    ON u.username = us.user_id AND us.contest_id = %s
                JOIN Contest con
                    ON con.contest_id = us.contest_id
                LEFT JOIN Problem pr
                    ON pr.contest_id = con.contest_id
                LEFT JOIN Code co
                    ON co.user_id = u.username
                    AND co.problem_id = pr.problem_id
                    AND co.accepted
                    AND co.submission_time <= con.end_time
                    AND co.submission_time = (
                        SELECT MAX(co2.submission_time)
                        FROM Code co2
                        WHERE
                            co2.accepted
                            AND co2.user_id = u.username
                            AND co2.problem_id = co.problem_id
                    )
                GROUP BY u.username
            ) sub;
            """, [contest_id])
        for user in score_board:
            for problem in select("select problem_id,name from Problem where contest_id=%s", [contest_id]):
                if (not select("select * from Code where user_id=%s and problem_id=%s and accepted=true", [user["username"], problem["problem_id"]])):
                    user[problem["name"]] = False
                else:
                    user[problem["name"]] = True
        all_problems = [problem["name"] for problem in select(
            "select name from Problem where contest_id=%s", [contest_id])]
        return Response({"score_board": score_board, "problems": all_problems}, status=200)


class GetSubmissions(AuthorizationMixin, MyListView):
    serializer = SubmissionSerializer

    def get_query_set(self, request):
        return select("select * from Code where user_id=%s order by submission_time desc", [request.COOKIES["username"]])


class SubmitCode(AuthorizationMixin, APIView):
    permission_classes = [HasAccessToProblem]

    def post(self, request):
        # Validate required fields
        if 'problem_id' not in request.data or 'file' not in request.FILES:
            return Response(
                {"error": "problem_id and file are required"},
                status=status.HTTP_400_BAD_REQUEST
            )

        problem_id = request.data['problem_id']
        submitted_file = request.FILES['file']

        try:
            # Validate file extension (example: allow only .py, .java, .cpp)
            allowed_extensions = [".cpp"]
            file_ext = os.path.splitext(submitted_file.name)[1].lower()
            if file_ext not in allowed_extensions:
                return Response(
                    {"error": f"Invalid file type. Allowed types: {', '.join(allowed_extensions)}"},
                    status=status.HTTP_400_BAD_REQUEST
                )

            # Generate unique filename
            unique_filename = f"submissions/{request.COOKIES['username']}/{uuid4().hex}{file_ext}"

            # Save the file
            file_path = default_storage.save(
                unique_filename,
                ContentFile(submitted_file.read())
            )
            print(file_path)

            execute(
                "INSERT INTO Code (user_id, problem_id, path, submission_time) VALUES (%s, %s, %s, %s)",
                [request.COOKIES["username"], problem_id,
                    unique_filename, datetime.now()], False
            )
            app.send_task('tasks.start', args=[select("select code_id from Code where user_id=%s and problem_id=%s and submission_time=(select max(submission_time) from Code where user_id=%s and problem_id=%s)", [
                          request.COOKIES["username"], problem_id, request.COOKIES["username"], problem_id])[0]["code_id"]])
            return Response({
                "message": "Code submitted successfully",
                "submission_id": uuid4().hex,
                "file_path": file_path
            }, status=status.HTTP_201_CREATED)

        except Exception as e:
            return Response(
                {"error": f"Submission failed: {str(e)}"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
