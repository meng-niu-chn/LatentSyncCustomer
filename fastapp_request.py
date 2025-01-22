import requests

# 定义接口的URL
url = "http://localhost:8000/run-inference"

# 定义要上传的文件
files = {
    "video_file": open("temp/video.mp4", "rb"),
    "audio_file": open("temp/audio.wav", "rb")
}

try:
    # 发送POST请求
    response = requests.post(url, files=files)

    # 检查响应状态码
    if response.status_code == 200:
        # 如果请求成功，保存生成的视频文件
        with open("test1.mp4", "wb") as f:
            f.write(response.content)
        print("Video file saved as test1.mp4")
    else:
        # 如果请求失败，打印错误信息
        print(f"Request failed with status code {response.status_code}")
        if response.headers.get("Content-Type") == "application/json":
            print(f"Error details: {response.json()}")
        else:
            print(f"Non-JSON response received: {response.text}")
        # print(f"Error details: {response.json()}")

except requests.exceptions.RequestException as e:
    # 处理请求过程中可能出现的异常
    print(f"An error occurred while making the request: {e}")

finally:
    # 确保文件被关闭
    for file in files.values():
        file.close()