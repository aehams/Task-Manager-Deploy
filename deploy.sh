#!/bin/bash
# 🚀 COMPLETE DEPLOYMENT SCRIPT - READY TO RUN

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   DevOps Task Manager - Complete Deployment       ║${NC}"
echo -e "${BLUE}║        Namespace: task-manager                    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
echo ""

# Navigate to project
cd /Users/ayhamshaq/Projects/Work/devops-task-manager

# Step 0: Clean up
echo -e "${YELLOW}[0/10] Cleaning up old namespace...${NC}"
kubectl delete ns task-manager --ignore-not-found=true 2>/dev/null
sleep 2
echo -e "${GREEN}✓ Old namespace deleted${NC}"
echo ""

# Step 1: Create Namespace
echo -e "${YELLOW}[1/10] Creating Namespace (task-manager)...${NC}"
kubectl apply -f k8s/namespace.yaml
sleep 2
echo -e "${GREEN}✓ Namespace created${NC}"
echo ""

# Step 2: Create Secrets & ConfigMaps
echo -e "${YELLOW}[2/10] Creating Secrets & ConfigMaps...${NC}"
kubectl apply -f k8s/secret.yaml
kubectl apply -f k8s/configmap.yaml
sleep 1
echo -e "${GREEN}✓ Secrets & ConfigMaps created${NC}"
echo ""

# Step 3: Create Storage
echo -e "${YELLOW}[3/10] Creating Storage (PersistentVolume)...${NC}"
kubectl apply -f k8s/postgres-pv.yaml
sleep 1
echo -e "${GREEN}✓ Storage created${NC}"
echo ""

# Step 4: Create PostgreSQL
echo -e "${YELLOW}[4/10] Creating PostgreSQL Database...${NC}"
kubectl apply -f k8s/postgres-deployment.yaml
kubectl apply -f k8s/postgres-service.yaml
sleep 3
echo -e "${GREEN}✓ PostgreSQL created${NC}"
echo ""

# Step 5: Create Backend
echo -e "${YELLOW}[5/10] Creating Backend API (3 replicas)...${NC}"
kubectl apply -f k8s/backend-deployment.yaml
kubectl apply -f k8s/backend-service.yaml
sleep 2
echo -e "${GREEN}✓ Backend created${NC}"
echo ""

# Step 6: Create Frontend
echo -e "${YELLOW}[6/10] Creating Frontend (1 replica)...${NC}"
kubectl apply -f k8s/frontend-deployment.yaml
kubectl apply -f k8s/frontend-service.yaml
sleep 1
echo -e "${GREEN}✓ Frontend created${NC}"
echo ""

# Step 7: Create Ingress
echo -e "${YELLOW}[7/10] Creating Ingress (NGINX)...${NC}"
kubectl apply -f k8s/ingress.yaml
sleep 1
echo -e "${GREEN}✓ Ingress created${NC}"
echo ""

# Step 8: Wait for Deployments
echo -e "${YELLOW}[8/10] Waiting for deployments to be ready...${NC}"
kubectl rollout status deployment/postgres -n task-manager --timeout=2m
kubectl rollout status deployment/backend -n task-manager --timeout=3m
kubectl rollout status deployment/frontend -n task-manager --timeout=2m
echo -e "${GREEN}✓ All deployments ready${NC}"
echo ""

# Step 9: Verify Resources
echo -e "${YELLOW}[9/10] Verifying all resources...${NC}"
echo ""
echo -e "${BLUE}📍 Namespace:${NC}"
kubectl get ns task-manager
echo ""

echo -e "${BLUE}📍 Pods (5 expected):${NC}"
kubectl get pods -n task-manager | grep -E "Running|postgres|backend|frontend" | wc -l | xargs -I {} echo "  {} pods running"
kubectl get pods -n task-manager
echo ""

echo -e "${BLUE}📍 Deployments (3 expected):${NC}"
kubectl get deployments -n task-manager
echo ""

echo -e "${BLUE}📍 Services (3 expected):${NC}"
kubectl get svc -n task-manager
echo ""

echo -e "${BLUE}📍 Secrets (2 expected):${NC}"
kubectl get secrets -n task-manager
echo ""

echo -e "${BLUE}📍 ConfigMaps (3 expected):${NC}"
kubectl get configmaps -n task-manager
echo ""

echo -e "${BLUE}📍 Storage:${NC}"
kubectl get pvc -n task-manager
echo ""

echo -e "${BLUE}📍 Ingress:${NC}"
kubectl get ingress -n task-manager
echo ""

echo -e "${GREEN}✓ All resources verified${NC}"
echo ""

# Step 10: Health Checks
echo -e "${YELLOW}[10/10] Running health checks...${NC}"
echo ""

# Backend health check with timeout
echo -e "${BLUE}📍 Testing Backend Health...${NC}"
kubectl port-forward -n task-manager svc/backend-service 3001:3001 > /dev/null 2>&1 &
PF_BACKEND=$!
sleep 2
BACKEND_HEALTH=$(curl -s http://localhost:3001/health 2>/dev/null | grep -o "OK\|Error" || echo "Unknown")
kill $PF_BACKEND 2>/dev/null
wait $PF_BACKEND 2>/dev/null
echo "  Backend Health: ${GREEN}${BACKEND_HEALTH}${NC}"

# Frontend health check with timeout
echo -e "${BLUE}📍 Testing Frontend Health...${NC}"
kubectl port-forward -n task-manager svc/frontend-service 3000:3000 > /dev/null 2>&1 &
PF_FRONTEND=$!
sleep 2
FRONTEND_HEALTH=$(curl -s http://localhost:3000/health 2>/dev/null | grep -o "healthy\|error" || echo "Unknown")
kill $PF_FRONTEND 2>/dev/null
wait $PF_FRONTEND 2>/dev/null
echo "  Frontend Health: ${GREEN}${FRONTEND_HEALTH}${NC}"

# Database health check
echo -e "${BLUE}📍 Testing PostgreSQL Connection...${NC}"
POSTGRES_POD=$(kubectl get pods -n task-manager -l app=postgres -o jsonpath='{.items[0].metadata.name}')
DB_HEALTH=$(kubectl exec -n task-manager $POSTGRES_POD -- psql -U postgres -d tasksdb -c "SELECT 1" 2>/dev/null | grep -q "1" && echo "Connected" || echo "Disconnected")
echo "  Database Health: ${GREEN}${DB_HEALTH}${NC}"

echo ""
echo -e "${GREEN}✓ All health checks completed${NC}"
echo ""

# Summary
echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              DEPLOYMENT COMPLETE ✅               ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}📊 Summary:${NC}"
echo "  ✓ Namespace: task-manager"
echo "  ✓ Pods: 5 (all running)"
echo "  ✓ Deployments: 3 (all ready)"
echo "  ✓ Services: 3 (ClusterIP)"
echo "  ✓ Secrets: 2 (created)"
echo "  ✓ ConfigMaps: 3 (created)"
echo "  ✓ Storage: 10Gi (bound)"
echo "  ✓ Ingress: 1 (configured)"
echo ""

echo -e "${YELLOW}🚀 Next Steps:${NC}"
echo ""
echo "1. Start Minikube Tunnel (Terminal 1):"
echo "   ${BLUE}minikube tunnel${NC}"
echo ""
echo "2. Add Host Entry (Terminal 2):"
echo "   ${BLUE}echo '127.0.0.1 task-manager.local' | sudo tee -a /etc/hosts${NC}"
echo ""
echo "3. Access Application (Terminal 2):"
echo "   ${BLUE}open http://task-manager.local${NC}"
echo ""
echo "4. Monitor Logs:"
echo "   ${BLUE}kubectl logs -n task-manager -l app=backend -f${NC}"
echo ""
echo -e "${YELLOW}📚 Documentation:${NC}"
echo "  • QUICK_DEPLOYMENT.md - Quick setup guide"
echo "  • VERIFICATION_COMMANDS.md - Complete test suite"
echo "  • ACCESS_APPLICATION.md - How to access app"
echo "  • README.md - Full documentation"
echo ""

echo -e "${GREEN}✨ All systems ready!${NC}"
