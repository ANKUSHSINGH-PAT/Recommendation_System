import pandas as pd
from langchain_core.documents import Document

class DataConverter:
    def __init__(self, data_path: str):
        self.data_path = data_path
    def convert(self):
        df= pd.read_csv(self.data_path)[['product_title','review']]
        docs=[
            Document(page_content=row['review'], metadata={"product_title": row['product_title']})
            for _, row in df.iterrows()
        ]
        return docs
