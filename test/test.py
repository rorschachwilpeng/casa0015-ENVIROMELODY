import requests
import logging
import json
import os
import time
from requests.exceptions import RequestException, Timeout

# 设置日志
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("stability_api_test.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Stability AI API配置
API_KEY = "sk-hzdHSi39PEEm3eaR0TrKqeeXf2Nu6grJhrLCbdwIu28jCXP2"  # 请替换为您的实际API密钥
BASE_URL = "https://api.stability.ai"
ENDPOINT = "/v2beta/audio/stable-audio-2/text-to-audio"

# 请求配置
AUDIO_PROMPT = "A song in the 3/4 time signature that features cello, live recorded drums, and rhythmic claps, The mood is calm and depressing."
OUTPUT_FORMAT = "mp3"
DURATION = 20  # 秒
STEPS = 30

def test_stability_api():
    """测试Stability AI API的连通性和音频生成功能"""
    
    logger.info("=== Stability AI API 测试开始 ===")
    
    # 构建请求参数
    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Accept": "audio/*"
    }
    
    data = {
        "prompt": AUDIO_PROMPT,
        "output_format": OUTPUT_FORMAT,
        "duration": DURATION,
        "steps": STEPS,
    }
    
    logger.info(f"请求端点: {BASE_URL}{ENDPOINT}")
    logger.info(f"生成提示词: {AUDIO_PROMPT}")
    logger.info(f"音频设置: 格式={OUTPUT_FORMAT}, 时长={DURATION}秒, 步数={STEPS}")
    
    # 创建输出目录（如果不存在）
    output_dir = "./output"
    os.makedirs(output_dir, exist_ok=True)
    output_path = f"{output_dir}/stability_audio_{int(time.time())}.{OUTPUT_FORMAT}"
    
    try:
        logger.info("发送API请求...")
        start_time = time.time()
        
        response = requests.post(
            f"{BASE_URL}{ENDPOINT}",
            headers=headers,
            files={"none": ""},  # 必须包含至少一个文件字段，即使是空的
            data=data,
            timeout=120  # 设置两分钟超时
        )
        
        elapsed_time = time.time() - start_time
        logger.info(f"请求完成，耗时: {elapsed_time:.2f}秒")
        logger.info(f"响应状态码: {response.status_code}")
        
        # 提取Content-Type以确认响应类型
        content_type = response.headers.get('Content-Type', '')
        logger.info(f"响应Content-Type: {content_type}")
        
        if response.status_code == 200:
            # 检查Content-Type确认我们收到了音频文件
            if 'audio/' in content_type:
                logger.info(f"成功接收音频数据，大小: {len(response.content)} 字节")
                with open(output_path, 'wb') as file:
                    file.write(response.content)
                logger.info(f"音频文件保存至: {output_path}")
                return True
            else:
                # 如果状态码是200但不是音频内容，记录并解析响应
                logger.warning("收到200状态码，但响应不是音频内容")
                try:
                    logger.warning(f"响应内容: {response.text[:500]}...")
                except:
                    logger.warning("无法读取响应文本内容")
                return False
        else:
            # 处理非200状态码
            logger.error(f"API请求失败: {response.status_code}")
            try:
                error_detail = response.json()
                logger.error(f"错误详情: {json.dumps(error_detail)}")
                
                # 检查常见错误原因
                if response.status_code == 401:
                    logger.error("授权错误: API密钥可能无效或已过期")
                elif response.status_code == 400:
                    logger.error("请求参数错误: 检查提示词、时长等参数")
                elif response.status_code == 429:
                    logger.error("请求频率过高: 已达到API限制")
                elif response.status_code >= 500:
                    logger.error("服务器错误: Stability AI服务可能暂时不可用")
            except:
                logger.error(f"无法解析错误响应: {response.text[:500]}")
            
            return False
            
    except Timeout:
        logger.error(f"请求超时: 超过120秒未收到响应")
        return False
    except RequestException as e:
        logger.error(f"请求异常: {str(e)}")
        return False
    except Exception as e:
        logger.error(f"测试过程中发生未知错误: {str(e)}")
        return False
    finally:
        logger.info("=== Stability AI API 测试结束 ===")

if __name__ == "__main__":
    test_result = test_stability_api()
    print(f"\n测试结果: {'成功' if test_result else '失败'}")
