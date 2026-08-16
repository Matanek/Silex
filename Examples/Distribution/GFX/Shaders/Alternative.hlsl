struct VertexOutput {
    float4 position : SV_Position;
};

VertexOutput vertex_main(uint id : SV_VertexID) {
    const float2 positions[3] = {
        float2(0.0, -0.5),
        float2(0.5, 0.5),
        float2(-0.5, 0.5)
    };
    VertexOutput output;
    output.position = float4(positions[id], 0.0, 1.0);
    return output;
}

float4 fragment_main(VertexOutput input) : SV_Target0 {
    return float4(0.2, 0.6, 1.0, 1.0);
}
