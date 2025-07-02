from helper import *


class ProblemSerializer(Serializer):
    fields = ['problem_id', 'name', 'rating', 'tags']
    tags = None

    def get_tags(self, obj):
        tags = select("select t.name from Tag_Problem tp JOIN Tag t On tp.tag_id = t.name where tp.problem_id=%s", [
                      obj['problem_id']])
        return [tag['name'] for tag in tags]


class TagSerializer(Serializer):
    fields = ['name']


class ContestSerializer(Serializer):
    fields = ['contest_id', 'name', 'start_time',
              'end_time', 'enrolled', 'status', 'is_admin']
    # status = None

    # def get_status(self, obj):
    #     if (obj['start_time'] < datetime.now()):
    #         if (obj['end_time'] > datetime.now()):
    #             return "ongoing"
    #         return "ended"
    #     return "upcoming"


class ProblemSpecificSerializer(Serializer):
    fields = ['problem_id', 'name', 'text', 'rating',
              'can_access_toturial']
    can_access_toturial = None

    def get_can_access_toturial(self, obj):
        return select("select end_time from Contest where contest_id = %s ", [obj["contest_id"]])[0]["end_time"] > datetime.now()


class ToturialSerializer(Serializer):
    fields = ['problem_id', 'text', "file"]


class ContestSpecificSerializer(Serializer):
    fields = ['contest_id', 'name', 'start_time',
              'end_time', 'problems', 'admins']
    problems = None
    admins = None

    def get_admins(self, obj):
        admins = select("select u.username from admin_contest ac JOIN \"User\" u ON ac.user_id = u.username where ac.contest_id = %s", [
                        obj["contest_id"]])
        return [admin['username'] for admin in admins]

    def get_problems(self, obj):
        problems = select("select p.problem_id,p.name,rating from Problem p where  contest_id=%s", [
                          obj['contest_id']])

        return [{"problem_id": problem['problem_id'], "name": problem['name'], "rating": problem['rating']} for problem in problems]


class SubmissionSerializer(Serializer):
    fields = ['code_id', 'problem_id',
              'problem_name', 'path', 'accepted', 'status']
    problem_name = None

    def get_problem_name(self, obj):
        return select("select name from Problem where problem_id = %s", [obj['problem_id']])[0]['name']
