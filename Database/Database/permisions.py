from rest_framework.permissions import BasePermission
from helper import select, execute


class IsAdminOfContest(BasePermission):
    message = "You are not admin of this contest"

    def has_permission(self, request, view):

        if (select("select exists(select from admin_contest where contest_id = %s and user_id = %s) as is_admin", [request.data["contest_id"], request.COOKIES["username"]])[0]["is_admin"]):
            return True
        return False


class HasAccessToProblem(BasePermission):
    message = "You are not allowed to access this question"

    def has_permission(self, request, view):

        is_admin_in_the_contest_containing_question = select("select exists( select * from Problem where Problem.problem_id = %s and Problem.contest_id in (select contest_id from admin_contest where user_id = %s)) as is_admin", [
                                                             request.data["problem_id"], request.COOKIES["username"]])[0]["is_admin"]
        contest_started = select("select exists(select * from Contest where Contest.contest_id = (select contest_id from Problem where problem_id = %s) and Contest.start_time < now()) as started", [
            request.data["problem_id"]])[0]["started"]
        return is_admin_in_the_contest_containing_question or contest_started


class HasAccessToContest(BasePermission):
    message = "You are not allowed to access this contest"

    def has_permission(self, request, view):
        print(request)
        is_admin_in_the_contest = select("select exists(select * from admin_contest ac where ac.contest_id = %s and ac.user_id = %s) as is_admin", [
            request.data["contest_id"], request.COOKIES["username"]])[0]["is_admin"]
        contest_started = select("select exists(select * from Contest where Contest.contest_id = %s and Contest.start_time < now()) as started", [
            request.data["contest_id"]])[0]["started"]
        return is_admin_in_the_contest or contest_started
