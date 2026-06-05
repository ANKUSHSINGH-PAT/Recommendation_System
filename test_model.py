import os
from langchain_groq import ChatGroq

llm = ChatGroq(
    groq_api_key=os.getenv("GROQ_API_KEY"),
    model=os.getenv("GROQ_MODEL")
)
print(llm("What is the capital of France?"))