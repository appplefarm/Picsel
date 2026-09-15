//
//  PhotoFocusSurface.metal
//  Picsel
//
//  Created by Jonghyeon Lee on 9/15/26.
//

#include <metal_stdlib>
#include <RealityKit/RealityKit.h>

using namespace metal;

[[visible]]
void photoFocusSurface(realitykit::surface_parameters params)
{
    // x: 초점 거리, y: 선명한 깊이 범위, z: 최대 블러 깊이, w: 최대 mip bias
    const float4 focus = params.uniforms().custom_parameter();

    // 실제 렌더링 중인 카메라 기준으로 계산해 관성·포커스 애니메이션도 연속적으로 따릅니다.
    const float depth = -params.uniforms().model_to_view()[3].z;
    const float depthError = abs(depth - focus.x);
    const float blurAmount = smoothstep(focus.y, focus.z, depthError);

    // 추가 텍스처나 다중 패스 없이, 이미 생성된 mipmap을 부드럽게 섞어 약하게 흐립니다.
    constexpr sampler photoSampler(address::clamp_to_edge, filter::linear, mip_filter::linear);
    float2 uv = params.geometry().uv0();
    uv.y = 1.0 - uv.y; // CGImage 텍스처를 기존 UnlitMaterial과 같은 방향으로 표시합니다.
    const half3 color = params.textures().base_color().sample(
        photoSampler,
        uv,
        bias(blurAmount * focus.w)
    ).rgb;
    const half3 tint = half3(params.material_constants().base_color_tint());
    params.surface().set_emissive_color(color * tint);
}
