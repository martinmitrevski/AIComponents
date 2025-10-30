//
//  SidebarView.swift
//  AIComponents
//
//  Created by ChatGPT on 29.10.25.
//

import SwiftUI

struct SidebarView<Menu: View, Content: View>: View {
    @Binding var isOpen: Bool
    var splitWidthRatio: CGFloat = 0.82
    var edgeActivationWidth: CGFloat = 32
    let excludedBottomHeight: CGFloat
    let menu: () -> Menu
    let content: () -> Content
    
    @State private var dragOffset: CGFloat = 0
    @State private var isDragActive = false
    
    private let sidebarAnimation = Animation.spring(response: 0.28, dampingFraction: 0.85)
    
    var body: some View {
        GeometryReader { geometry in
            let splitWidth = geometry.size.width * splitWidthRatio
            let clampedDrag = max(-splitWidth, min(splitWidth, dragOffset))
            let mainOffset = isOpen ? (splitWidth + min(0, clampedDrag)) : max(0, clampedDrag)
            let panelOffset = isOpen ? min(0, clampedDrag) : (-splitWidth + max(0, clampedDrag))
            let availableHeight = max(0, geometry.size.height - excludedBottomHeight)
            let contentGesture = splitDragGesture(splitWidth: splitWidth, availableHeight: availableHeight)
            let overlayGesture = splitDragGesture(splitWidth: splitWidth, availableHeight: nil)
            
            ZStack(alignment: .leading) {
                content()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .offset(x: mainOffset)
                    .simultaneousGesture(contentGesture, including: .gesture)
                
                if isOpen {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                        .onTapGesture {
                            closeSplitView(animated: true)
                        }
                        .gesture(overlayGesture)
                }
                
                if isOpen || clampedDrag > 0 {
                    menu()
                        .frame(width: splitWidth)
                        .offset(x: panelOffset)
                        .transition(.move(edge: .leading))
                        .shadow(color: .black.opacity(0.15), radius: 12, x: 4, y: 0)
                        .background(Color.white)
                }
            }
            .animation(sidebarAnimation, value: isOpen)
            .animation(sidebarAnimation, value: dragOffset)
        }
        .onChange(of: isOpen) { _, newValue in
            if !newValue {
                dragOffset = 0
                isDragActive = false
            }
        }
    }
    
    private func splitDragGesture(splitWidth: CGFloat, availableHeight: CGFloat?) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onChanged { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                
                if !isOpen && !isDragActive && value.startLocation.x > edgeActivationWidth {
                    return
                }
                
                if let availableHeight, value.startLocation.y > availableHeight {
                    return
                }
                if abs(horizontal) < abs(vertical) {
                    return
                }
                
                if !isDragActive {
                    isDragActive = true
                }
                
                if isOpen {
                    dragOffset = min(0, horizontal)
                } else if horizontal > 0 {
                    dragOffset = horizontal
                }
            }
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                
                defer {
                    dragOffset = 0
                    isDragActive = false
                }
                
                if !isOpen && value.startLocation.x > edgeActivationWidth {
                    return
                }
                if let availableHeight, value.startLocation.y > availableHeight {
                    return
                }
                if abs(horizontal) < abs(vertical) {
                    return
                }
                if isOpen {
                    if horizontal < -splitWidth * 0.2 {
                        closeSplitView(animated: true)
                    }
                } else if horizontal > splitWidth * 0.2 {
                    openSplitView()
                }
            }
    }
    
    private func openSplitView() {
        withAnimation(sidebarAnimation) {
            isOpen = true
            dragOffset = 0
        }
    }
    
    private func closeSplitView(animated: Bool) {
        let animation = animated ? sidebarAnimation : nil
        if let animation {
            withAnimation(animation) {
                isOpen = false
            }
        } else {
            isOpen = false
        }
        dragOffset = 0
        isDragActive = false
    }
}
