from fastapi import FastAPI, HTTPException, UploadFile, File, BackgroundTasks
from fastapi.responses import FileResponse
import shutil
import subprocess
import logging
import os
import select
import uuid

# 配置日志
logging.basicConfig(
    level=logging.INFO,  # 设置日志级别为 INFO
    format="%(asctime)s - %(levelname)s - %(message)s",  # 日志格式
    handlers=[
        logging.StreamHandler(),  # 输出到终端
        logging.FileHandler("inference.log")  # 输出到文件
    ]
)

app = FastAPI()

# 确保 assets 目录存在
os.makedirs("assets", exist_ok=True)

def run_inference_script(video_path, audio_path, output_video_path):
    try:
        # 确保脚本路径正确
        script_path = "./fastapp_inference.sh"
        subprocess.run(
            [script_path, video_path, audio_path, output_video_path],
            check=True,  # 检查脚本是否成功执行
            capture_output=True,  # 捕获标准输出和错误
            text=True  # 将输出转换为字符串
        )
    except subprocess.CalledProcessError as e:
        # 打印脚本的错误日志
        logging.error(f"Script failed with error: {e.stderr}")
        raise HTTPException(status_code=500, detail={
            'status': 'error',
            'output': e.stdout,
            'error': e.stderr
        })
    except Exception as e:
        logging.error(f"An error occurred: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/run-inference")
async def run_inference(
    video_file: UploadFile = File(...),  # 接收视频文件
    audio_file: UploadFile = File(...),  # 接收音频文件
    background_tasks: BackgroundTasks = BackgroundTasks()  # 添加 BackgroundTasks
):
    # 初始化 request_dir 为 None
    request_dir = None

    try:
        # 为每个请求生成唯一目录
        request_id = str(uuid.uuid4())
        request_dir = os.path.join("assets", request_id)
        os.makedirs(request_dir, exist_ok=True)

        # 保存视频文件
        video_path = os.path.join(request_dir, "demo1_video.mp4")
        with open(video_path, "wb") as video_buffer:
            video_buffer.write(await video_file.read())
        logging.info(f"Video file saved to {video_path}")

        # 保存音频文件
        audio_path = os.path.join(request_dir, "demo1_audio.wav")
        with open(audio_path, "wb") as audio_buffer:
            audio_buffer.write(await audio_file.read())
        logging.info(f"Audio file saved to {audio_path}")

        # 生成的视频文件路径
        output_video_path = os.path.join(request_dir, "video_out.mp4")

        # 执行 ./fastapp_inference.sh 并传递动态路径
        logging.info(f"Running script with video_path={video_path}, audio_path={audio_path}, output_video_path={output_video_path}")
        run_inference_script(video_path, audio_path, output_video_path)

        # 检查生成的视频文件是否存在
        if not os.path.exists(output_video_path):
            raise HTTPException(status_code=500, detail="Generated video file not found")

        # 返回生成的视频文件，并在后台清理临时目录
        background_tasks.add_task(cleanup_temp_dir, request_dir)  # 添加后台任务
        return FileResponse(output_video_path, media_type="video/mp4", filename="output.mp4")

    except subprocess.CalledProcessError as e:
        # 打印脚本的错误日志
        logging.error(f"Script failed with error: {e.stderr}")
        # 抛出 HTTP 异常
        raise HTTPException(status_code=500, detail={
            'status': 'error',
            'output': e.stdout,
            'error': e.stderr
        })
    except Exception as e:
        # 处理其他异常
        logging.error(f"An error occurred: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

# 清理临时目录的函数
def cleanup_temp_dir(request_dir: str):
    if request_dir and os.path.exists(request_dir):
        logging.info(f"removing {request_dir}")
        shutil.rmtree(request_dir)

if __name__ == '__main__':
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)