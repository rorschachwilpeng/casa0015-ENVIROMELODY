# # deepseek_api_test.py

# # 请先安装 OpenAI SDK: pip install openai

# import sys
# from openai import OpenAI

# def test_deepseek_api(api_key, prompt="你好，请简要描述一下如何根据天气生成音乐。"):
#     """测试 DeepSeek API 连接和功能"""
#     try:
#         # 初始化客户端
#         client = OpenAI(api_key=api_key, base_url="https://api.deepseek.com")
        
#         # 构建系统提示
#         system_content = """
#         你是一位专业的音乐提示工程师，擅长将环境数据和音乐偏好转化为高质量的音乐生成提示。
#         你的任务是根据天气数据和用户偏好，创建一个详细、有创意、富有表现力的提示，用于生成音乐。
#         """
        
#         # 创建聊天完成请求
#         print("正在发送请求到 DeepSeek API...")
#         response = client.chat.completions.create(
#             model="deepseek-chat",
#             messages=[
#                 {"role": "system", "content": system_content},
#                 {"role": "user", "content": prompt},
#             ],
#             temperature=0.7,
#             max_tokens=300,
#             stream=False
#         )
        
#         # 打印结果
#         print("\n=== API 响应成功 ===")
#         print(f"模型: {response.model}")
#         print(f"完成原因: {response.choices[0].finish_reason}")
#         print("\n生成的内容:")
#         print(response.choices[0].message.content)
#         print("\n=== 测试成功完成 ===")
        
#     except Exception as e:
#         print(f"\n!!! 错误: {e}")
#         print("请检查你的 API 密钥是否正确，以及网络连接是否正常。")
#         return False
        
#     return True

# if __name__ == "__main__":
#     # 从命令行参数获取 API 密钥
#     if len(sys.argv) < 2:
#         print("请提供 DeepSeek API 密钥作为命令行参数")
#         print("用法: python deepseek_api_test.py <你的API密钥> [可选:自定义提示文本]")
#         sys.exit(1)
        
#     api_key = sys.argv[1]
    
#     # 可选: 从命令行获取自定义提示
#     custom_prompt = None
#     if len(sys.argv) >= 3:
#         custom_prompt = sys.argv[2]
        
#     # 运行测试
#     test_deepseek_api(api_key, custom_prompt)


# Please install OpenAI SDK first: `pip3 install openai`

from openai import OpenAI

client = OpenAI(api_key="sk-fe8c07ad4d344b65856bb0fe6beed2ac", base_url="https://api.deepseek.com")

response = client.chat.completions.create(
    model="deepseek-chat",
    messages=[
        {"role": "system", "content": "You are a helpful assistant"},
        {"role": "user", "content": "Hello"},
    ],
    stream=False
)

print(response.choices[0].message.content)