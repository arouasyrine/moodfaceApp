import mediapipe as mp
print(dir(mp))
try:
    print(mp.solutions)
    print("Success: mp.solutions exists")
except AttributeError:
    print("Failure: mp.solutions does not exist")

import mediapipe.python.solutions as solutions
print("Success: imported mediapipe.python.solutions directly")
