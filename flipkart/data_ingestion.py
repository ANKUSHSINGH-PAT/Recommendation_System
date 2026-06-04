from langchain_astradb import AstraDBVectorStore
from langchain_huggingface import HuggingFaceEmbeddings
from flipkart.data_converter import DataConverter
from flipkart.config import Config

class DataIngestor:
    def __init__(self):
        self.embeddings = HuggingFaceEmbeddings(model=Config.EMBEDDING_MODEL)
        self.vstore= AstraDBVectorStore(
            api_endpoint=Config.ASTRA_DB_API_ENDPOINT,
            token=Config.ASTRA_DB_APPLICATION_TOKEN,
            namespace=Config.ASTRA_DB_KEYSPACE,
            collection_name="flipkartdB",
            embedding=self.embeddings
        )
    def ingest(self, load_existing):
        if load_existing == True:
            return self.vstore
        docs=DataConverter("data\\flipkart_product_review.csv").convert()
        self.vstore.add_documents(docs)
        return self.vstore
    

if __name__ == "__main__":
    ingestor = DataIngestor()
    ingestor.ingest(load_existing=False)
