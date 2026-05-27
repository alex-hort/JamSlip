//
//  FollowingFeedView.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 24/01/26.
//
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct FollowingFeedView: View {
    let isSelected: Bool
    
    @State private var currentIndex: Int = 0
    @StateObject private var vm = FollowingFeedViewModel.shared // ✅ Persiste entre navegaciones
    @ObservedObject private var audioPlayer = AudioPlayerManager.shared
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if vm.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    Text("Cargando...")
                        .foregroundColor(.white.opacity(0.6))
                }
            } else if vm.followingJams.isEmpty {
                emptyState
            } else {
                GeometryReader { geo in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 0) {
                            ForEach(Array(vm.followingJams.enumerated()), id: \.element.id) { index, jam in
                                FollowingJamCardView(jam: jam)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 10)
                                    .padding(.bottom, 50)
                                    .frame(
                                        width: geo.size.width,
                                        height: geo.size.height
                                    )
                                    .scrollTransition { content, phase in
                                        content
                                            .scaleEffect(
                                                x: phase.isIdentity ? 1.0 : 0.85,
                                                y: phase.isIdentity ? 1.0 : 0.85
                                            )
                                            .rotation3DEffect(
                                                .degrees(phase.value * -15),
                                                axis: (x: 0, y: 1, z: 0),
                                                perspective: 0.5
                                            )
                                            .opacity(phase.isIdentity ? 1.0 : 0.7)
                                            .blur(radius: phase.isIdentity ? 0 : 3)
                                    }
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.paging)
                    .scrollPosition(id: Binding(
                        get: {
                            vm.followingJams.indices.contains(currentIndex)
                            ? vm.followingJams[currentIndex].id
                            : nil
                        },
                        set: { newId in
                            if let newId = newId,
                               let index = vm.followingJams.firstIndex(where: { $0.id == newId }),
                               currentIndex != index {
                                currentIndex = index
                                if isSelected {
                                    audioPlayer.playJam(vm.followingJams[index])
                                }
                            }
                        }
                    ))
                }
            }
        }
        .ignoresSafeArea()
        .task {
            // ✅ Solo carga si no hay datos — instantáneo si ya cargó antes
            await vm.startListeningIfNeeded()
            
            // ✅ Si ya hay jams y la tab está seleccionada, reproducir
            if isSelected && !vm.followingJams.isEmpty && vm.followingJams.indices.contains(currentIndex) {
                audioPlayer.playJam(vm.followingJams[currentIndex])
            }
        }
        .onChange(of: isSelected) { _, newValue in
            if newValue {
                if !vm.followingJams.isEmpty && vm.followingJams.indices.contains(currentIndex) {
                    audioPlayer.playJam(vm.followingJams[currentIndex])
                }
            } else {
                audioPlayer.pause()
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.wave.2")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.3))
            
            Text("No jams from people you follow")
                .font(.headline)
                .foregroundColor(.white.opacity(0.6))
            
            Text("Follow more users to see their jams here")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}
