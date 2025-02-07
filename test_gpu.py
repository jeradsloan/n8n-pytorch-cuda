import torch
import time

def test_gpu_performance():
    # Create two random matrices on GPU
    size = 2000
    print(f"\nRunning matrix multiplication test with {size}x{size} matrices...")
    
    # Warm up GPU
    torch.cuda.synchronize()
    
    a = torch.randn(size, size, device='cuda')
    b = torch.randn(size, size, device='cuda')
    
    # Time the matrix multiplication
    torch.cuda.synchronize()
    start_time = time.time()
    
    c = torch.matmul(a, b)
    
    torch.cuda.synchronize()
    end_time = time.time()
    
    print(f"Matrix multiplication completed in: {end_time - start_time:.4f} seconds")
    
    # Memory usage
    print("\nGPU Memory Usage:")
    print(f"Allocated: {torch.cuda.memory_allocated() / 1024**2:.1f} MB")
    print(f"Cached: {torch.cuda.memory_reserved() / 1024**2:.1f} MB")

if __name__ == "__main__":
    # Print system info
    print("System Information:")
    print(f"PyTorch Version: {torch.__version__}")
    print(f"CUDA Available: {torch.cuda.is_available()}")
    if torch.cuda.is_available():
        print(f"CUDA Version: {torch.version.cuda}")
        print(f"GPU Device: {torch.cuda.get_device_name(0)}")
        
        # Run the performance test
        test_gpu_performance()
    else:
        print("No CUDA GPU available!")
