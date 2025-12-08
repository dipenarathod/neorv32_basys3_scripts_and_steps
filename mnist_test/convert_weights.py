import numpy as np
import tensorflow as tf
from pathlib import Path

model_path="mnist_model.keras" 
output_path=Path("exported_weights_q07")
using_q07=True

def quantize_q07(x):
    x_clipped=np.clip(x, -1.0, 0.9921875) #Restrict weights in the numpy array to -1 to 127/128
    q=np.round(x_clipped * 128.0).astype(np.int16) #128=scaling factor
                                                     #int16 is used in the intermediate step 
                                                     #similar to our calculations in VHDL
    q=np.clip(q, -128, 127).astype(np.int8)       #Clip to int8
    return q

def write_weights_array(f, name, weights):
    flat=weights.astype(np.int8).flatten()
    f.write(name + "\n")

    for i, v in enumerate(flat):
        f.write(str(int(v)))  #avoid scientific notation

        #Add comma (if not the last element)
        #Want to ease copy pasting
        if(i != flat.size - 1):
            f.write(", ")

        #Newline after every 20 values (except after the very last one)
        if((i + 1) % 20 == 0):
            f.write("\n")
    #savetxt approach - bad because we need to pad zeros if we want reshape matrix as a 2D matrix




def main():
    output_path.mkdir(parents=True, exist_ok=True)
    model=tf.keras.models.load_model(model_path)
    for layer_index, layer in enumerate(model.layers):
        weights=layer.get_weights()
        if not weights:
            #Skipping layers without weights
            continue

        base_name=f"layer_{layer_index}_{layer.name}"
        header_path=output_path / f"{base_name}.txt"

        with open(header_path, "w") as f:
            if(len(weights) == 2): #weights and biases both
                w, b=weights
                if(using_q07):
                    w=quantize_q07(w)
                    b=quantize_q07(b)
                write_weights_array(f, f"{base_name}_weights", w)
                f.write("\n")
                write_weights_array(f, f"{base_name}_bias", b)

            else:
                for p_index, p in enumerate(weights):
                    if(using_q07):
                        p=quantize_q07(p)
                    write_weights_array(f, f"{base_name}_p{p_index}", p)


if __name__ == "__main__":
    main()
