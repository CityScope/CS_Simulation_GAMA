import numpy as np
from numpy import arange
from numpy import savetxt
from numpy import concatenate
from sklearn.metrics import r2_score
from sklearn.metrics import mean_squared_error
from sklearn.model_selection import train_test_split
from sklearn.linear_model import LinearRegression
from sklearn.preprocessing import PolynomialFeatures
from sklearn import tree
from sklearn.pipeline import make_pipeline
from sklearn.neighbors import KNeighborsRegressor
from math import sqrt
import matplotlib.pyplot as plt

log = []
train_features = []
train_results = []
test_features = []
test_results = []
results_mas = []
T = []



estimators = [ #different ML estimators can be used and tested
    #('linear', LinearRegression()),
    ('decision_tree', tree.DecisionTreeRegressor()),
    #('kNN_uniform', KNeighborsRegressor())
]

importedData = np.loadtxt(open("DiversityIncentive.csv", "rb"), delimiter = ",") #Should include the first case of current situation (no built area)


for i in range(50): #Shuffle Data 50 times
    np.random.shuffle(importedData)


index = int(round(importedData.shape[0]*0.8))


train_features0 = importedData[0:index,0:2]
train_results0 = importedData[0:index,2:18]
test_features0 = importedData[index:importedData.shape[0],0:2]
test_results0 = importedData[index:importedData.shape[0],2:18]



def R_squared(predictedVals, expectedVals):
    errorPropSelectedCity = sqrt(mean_squared_error(expectedVals[:,0], predictedVals[:,0], sample_weight=None, multioutput='uniform_average', squared='True'))
    errorPropProf1 = sqrt(mean_squared_error(expectedVals[:,1], predictedVals[:,1], sample_weight=None, multioutput='uniform_average', squared='True'))
    errorPropProf2 = sqrt(mean_squared_error(expectedVals[:, 2], predictedVals[:, 2], sample_weight=None, multioutput='uniform_average', squared='True'))
    errorPropProf3 = sqrt(mean_squared_error(expectedVals[:, 3], predictedVals[:, 3], sample_weight=None, multioutput='uniform_average',squared='True'))
    errorPropProf4 = sqrt(mean_squared_error(expectedVals[:, 4], predictedVals[:, 4], sample_weight=None, multioutput='uniform_average', squared='True'))
    errorPropProf5 = sqrt(mean_squared_error(expectedVals[:, 5], predictedVals[:, 5], sample_weight=None, multioutput='uniform_average', squared='True'))
    errorPropProf6 = sqrt(mean_squared_error(expectedVals[:, 6], predictedVals[:, 6], sample_weight=None, multioutput='uniform_average',squared='True'))
    errorPropProf7 = sqrt(mean_squared_error(expectedVals[:, 7], predictedVals[:, 7], sample_weight=None, multioutput='uniform_average',squared='True'))
    errorPropProf8 = sqrt(mean_squared_error(expectedVals[:, 8], predictedVals[:, 8], sample_weight=None, multioutput='uniform_average',squared='True'))
    errorPropCar = sqrt(mean_squared_error(expectedVals[:, 9], predictedVals[:, 9], sample_weight=None, multioutput='uniform_average',squared='True'))
    errorPropBus = sqrt(mean_squared_error(expectedVals[:, 10], predictedVals[:, 10], sample_weight=None, multioutput='uniform_average',squared='True'))
    errorPropT = sqrt(mean_squared_error(expectedVals[:, 11], predictedVals[:, 11], sample_weight=None, multioutput='uniform_average',squared='True'))
    errorPropBike = sqrt(mean_squared_error(expectedVals[:, 12], predictedVals[:, 12], sample_weight=None, multioutput='uniform_average',squared='True'))
    errorPropWalking = sqrt(mean_squared_error(expectedVals[:, 13], predictedVals[:, 13], sample_weight=None, multioutput='uniform_average',squared='True'))
    errorTime = sqrt(mean_squared_error(expectedVals[:, 14], predictedVals[:, 14], sample_weight=None, multioutput='uniform_average',squared='True'))
    errorDist = sqrt(mean_squared_error(expectedVals[:, 15], predictedVals[:, 15], sample_weight=None, multioutput='uniform_average',squared='True'))
    print("Error prop Kendall " + str(errorPropSelectedCity))
    print("Error prop Prof1 " + str(errorPropProf1))
    print("Error prop Prof2 " + str(errorPropProf2))
    print("Error prop Prof3 " + str(errorPropProf3))
    print("Error prop Prof4 " + str(errorPropProf4))
    print("Error prop Prof5 " + str(errorPropProf5))
    print("Error prop Prof6 " + str(errorPropProf6))
    print("Error prop Prof7 " + str(errorPropProf7))
    print("Error prop Prof7 " + str(errorPropProf7))
    print("Error prop Prof8 " + str(errorPropProf8))
    print("Error prop Car " + str(errorPropCar))
    print("Error prop Bus " + str(errorPropBus))
    print("Error prop T " + str(errorPropT))
    print("Error prop Bike " + str(errorPropBike))
    print("Error prop Walking " + str(errorPropWalking))
    print("Error comm time " + str(errorTime))
    print("Error comm distance " + str(errorDist))
    print("R2 score " + str(r2_score(expectedVals,predictedVals)))

def predictions(X_train,Y_train,X_test,Y_test,mat):
    for name, estimator in estimators:
            estimator.fit(X_train, Y_train)
            Y_predicted = estimator.predict(X_test)
            R_squared(Y_predicted, Y_test)
            Y_extra = estimator.predict(mat)

    fig = plt.figure()
    ax = fig.add_subplot(221)
    ax.plot(range(0,Y_predicted.shape[0]), Y_predicted[:,0], 'o',label='yPredicted')
    ax.plot(range(0,Y_test.shape[0]), Y_test[:,0],'o', label='ytest')
    plt.title('Proportion of people living in Selected City')
    plt.ylabel('Proportion')


    ax2 = fig.add_subplot(222)
    ax2.plot(range(0, Y_predicted.shape[0]), Y_predicted[:, 9], 'o', label='yPredicted')
    ax2.plot(range(0, Y_test.shape[0]), Y_test[:, 9], 'o', label='ytest')
    plt.title('Proportion of cars')
    plt.ylabel('Proportion')


    ax3 = fig.add_subplot(223)
    ax3.plot(range(0, Y_predicted.shape[0]), Y_predicted[:, 10], 'o', label='yPredicted')
    ax3.plot(range(0, Y_test.shape[0]), Y_test[:, 10], 'o', label='ytest')
    plt.title('Proportion of bus')
    plt.ylabel('Proportion')


    ax3 = fig.add_subplot(224)
    ax3.plot(range(0, Y_predicted.shape[0]), Y_predicted[:, 11], 'o', label='yPredicted')
    ax3.plot(range(0, Y_test.shape[0]), Y_test[:, 11], 'o', label='ytest')
    plt.title('Proportion of T')
    plt.ylabel('Proportion')


    fig1 = plt.figure()
    ax4 = fig1.add_subplot(221)
    ax4.plot(range(0, Y_predicted.shape[0]), Y_predicted[:, 12], 'o', label='yPredicted')
    ax4.plot(range(0, Y_test.shape[0]), Y_test[:, 12], 'o', label='ytest')
    plt.title('Proportion of bike')
    plt.ylabel('Proportion')


    ax5 = fig1.add_subplot(222)
    ax5.plot(range(0, Y_predicted.shape[0]), Y_predicted[:, 13], 'o', label='yPredicted')
    ax5.plot(range(0, Y_test.shape[0]), Y_test[:, 13], 'o', label='ytest')
    plt.title('Proportion walking')
    plt.ylabel('Proportion')


    ax6 = fig1.add_subplot(223)
    ax6.plot(range(0, Y_predicted.shape[0]), Y_predicted[:, 14], 'o', label='yPredicted')
    ax6.plot(range(0, Y_test.shape[0]), Y_test[:, 14], 'o', label='ytest')
    plt.title('mean commuting time')
    plt.ylabel('time[min]')


    ax2 = fig1.add_subplot(224)
    ax2.plot(range(0, Y_predicted.shape[0]), Y_predicted[:, 15], 'o', label='yPredicted')
    ax2.plot(range(0, Y_test.shape[0]), Y_test[:, 15], 'o', label='ytest')
    plt.title('mean commuting distance')
    plt.ylabel('distance[m]')

    plt.show()
    return Y_extra



cont = 0
mat = np.zeros((5670, 2))
mat[0,:] = importedData[0,0:1] #first case (current non-built situation)
for price in arange(0,1.05,0.05):
    for area in range(10000, 2710000, 10000):
        mat[cont,0] = area
        mat[cont,1] = price
        cont = cont + 1


results_mas=predictions(train_features0,train_results0,test_features0,test_results0,mat)

savetxt("MLResultsDiversityIncentive.csv", results_mas, delimiter=",")

