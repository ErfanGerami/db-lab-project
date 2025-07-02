import os
os.system("g++ /app/shared/code/code.cpp -o /app/shared/code/code.out ")
os.system("chmod +x /app/shared/code/code.out")

for input in os.listdir('/app/shared/inputs'):
    os.system(
        f"/app/shared/code/code.out < /app/shared/inputs/{input} > /app/shared/outputs/{input} 2> /app/shared/outputs/{input}.err")

print("Execution completed")
