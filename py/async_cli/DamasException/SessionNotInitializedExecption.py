from http.client import HTTPException


class SessionNotInitializedExecption(HTTPException):
    def __init__(self, session):
        self.msg_error = "Damas Error : The {} session is not initialized".format(session)

    def throw(self, details="no more details"):
        print(self.msg_error + details)
