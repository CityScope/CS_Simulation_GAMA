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
import random

nameFileIN = "KendallFancyIncentive.csv"
nameFileOUT = "MLResultsKendallFancyIncentiveK.csv"
nameGraph1 = "KendallFancyIncentive1K.png"
nameGraph2 = "KendallFancyIncentive2K.png"
nameGraph3 = "KendallFancyIncentive3K.png"
nameStatFile = "KendallFancyIncentiveStatsK.csv"
max_seedValue = 20000

log = []
train_features = []
train_results = []
test_features = []
test_results = []
results_mas = []
results_mas_final = []
R2_final = 0
test_predicted_final = []
test_simulated_final = []
T = []



estimators = [ #different ML estimators can be used and tested
    # ('linear', LinearRegression()),
    #('decision_tree', tree.DecisionTreeRegressor(criterion = 'mse', max_depth = 5)),
    #('decision_tree', tree.DecisionTreeRegressor()),
    ('kNN_uniform', KNeighborsRegressor(n_neighbors=4, weights='distance'))
    #('kNN_uniform', KNeighborsRegressor(n_neighbors=8))
]


importedDataRaw = np.loadtxt(open(nameFileIN, "rb"), delimiter=",")  # Should include the first case of current situation (no built area)

def R_squared(predictedVals,expectedVals):
    R2_value_calc = r2_score(expectedVals, predictedVals)
    return R2_value_calc

def R_squaredText(predictedVals, expectedVals):
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
    errorVolpeOccupancy = sqrt(mean_squared_error(expectedVals[:, 16], predictedVals[:, 16], sample_weight=None, multioutput='uniform_average',squared='True'))
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
    print("Volpe Occupancy Error " + str(errorVolpeOccupancy))
    print("R2 score " + str(r2_score(expectedVals,predictedVals)))
    print("R2 score Kendall " + str(r2_score(expectedVals[:,0], predictedVals[:,0])))
    print("R2 score Prof1 " + str(r2_score(expectedVals[:, 1], predictedVals[:, 1])))
    print("R2 score Prof2 " + str(r2_score(expectedVals[:, 2], predictedVals[:, 2])))
    print("R2 score Prof3 " + str(r2_score(expectedVals[:, 3], predictedVals[:, 3])))
    print("R2 score Prof4 " + str(r2_score(expectedVals[:, 4], predictedVals[:, 4])))
    print("R2 score Prof5 " + str(r2_score(expectedVals[:, 5], predictedVals[:, 5])))
    print("R2 score Prof6 " + str(r2_score(expectedVals[:, 6], predictedVals[:, 6])))
    print("R2 score Prof7 " + str(r2_score(expectedVals[:, 7], predictedVals[:, 7])))
    print("R2 score Prof8 " + str(r2_score(expectedVals[:, 8], predictedVals[:, 8])))
    print("R2 score Car " + str(r2_score(expectedVals[:, 9], predictedVals[:, 9])))
    print("R2 score Bus " + str(r2_score(expectedVals[:, 10], predictedVals[:, 10])))
    print("R2 score T " + str(r2_score(expectedVals[:, 11], predictedVals[:, 11])))
    print("R2 score Bike " + str(r2_score(expectedVals[:, 12], predictedVals[:, 12])))
    print("R2 score Walking " + str(r2_score(expectedVals[:, 13], predictedVals[:, 13])))
    print("R2 score time " + str(r2_score(expectedVals[:, 14], predictedVals[:, 14])))
    print("R2 score distance " + str(r2_score(expectedVals[:, 15], predictedVals[:, 15])))
    print("R2 score Volpe occ " + str(r2_score(expectedVals[:, 16], predictedVals[:, 16])))
    errors = [errorPropSelectedCity, errorPropProf1, errorPropProf2, errorPropProf3, errorPropProf4, errorPropProf5, errorPropProf6, errorPropProf7, errorPropProf8, errorPropCar, errorPropBus, errorPropT, errorPropBike, errorPropWalking, errorTime, errorDist, errorVolpeOccupancy, (r2_score(expectedVals,predictedVals))]
    return errors


def predictions(X_train,Y_train,X_test,Y_test,mat):
    for name, estimator in estimators:
            estimator.fit(X_train, Y_train)
            Y_predicted = estimator.predict(X_test)
            R2value_indiv = R_squared(Y_predicted, Y_test)
            Y_extra = estimator.predict(mat)
    return R2value_indiv, Y_extra,Y_predicted

def showGraphs(R2,Y_simulated,Y_predicted):

    fig = plt.figure()
    manager = plt.get_current_fig_manager()
    manager.resize(*manager.window.maxsize())
    ax = fig.add_subplot(221)
    ax.plot(range(0, Y_predicted.shape[0]), Y_predicted[:, 0], 'o', label='yPredicted')
    ax.plot(range(0, Y_simulated.shape[0]), Y_simulated[:, 0], 'o', label='ysimulated')
    plt.title('Proportion of people living in Selected City')
    plt.ylabel('Proportion')

    ax2 = fig.add_subplot(222)
    ax2.plot(range(0, Y_predicted.shape[0]), Y_predicted[:, 9], 'o', label='yPredicted')
    ax2.plot(range(0, Y_simulated.shape[0]), Y_simulated[:, 9], 'o', label='ysimulated')
    plt.title('Proportion of cars')
    plt.ylabel('Proportion')

    ax3 = fig.add_subplot(223)
    ax3.plot(range(0, Y_predicted.shape[0]), Y_predicted[:, 10], 'o', label='yPredicted')
    ax3.plot(range(0, Y_simulated.shape[0]), Y_simulated[:, 10], 'o', label='ysimulated')
    plt.title('Proportion of bus')
    plt.ylabel('Proportion')

    ax3 = fig.add_subplot(224)
    ax3.plot(range(0, Y_predicted.shape[0]), Y_predicted[:, 11], 'o', label='yPredicted')
    ax3.plot(range(0, Y_simulated.shape[0]), Y_simulated[:, 11], 'o', label='ysimulated')
    plt.title('Proportion of T')
    plt.ylabel('Proportion')

    fig.savefig(nameGraph1)

    fig1 = plt.figure()
    manager = plt.get_current_fig_manager()
    manager.resize(*manager.window.maxsize())
    ax4 = fig1.add_subplot(221)
    ax4.plot(range(0, Y_predicted.shape[0]), Y_predicted[:, 12], 'o', label='yPredicted')
    ax4.plot(range(0, Y_simulated.shape[0]), Y_simulated[:, 12], 'o', label='ysimulated')
    plt.title('Proportion of bike')
    plt.ylabel('Proportion')

    ax5 = fig1.add_subplot(222)
    ax5.plot(range(0, Y_predicted.shape[0]), Y_predicted[:, 13], 'o', label='yPredicted')
    ax5.plot(range(0, Y_simulated.shape[0]), Y_simulated[:, 13], 'o', label='ysimulated')
    plt.title('Proportion walking')
    plt.ylabel('Proportion')

    ax6 = fig1.add_subplot(223)
    ax6.plot(range(0, Y_predicted.shape[0]), Y_predicted[:, 14], 'o', label='yPredicted')
    ax6.plot(range(0, Y_simulated.shape[0]), Y_simulated[:, 14], 'o', label='ysimulated')
    plt.title('mean commuting time')
    plt.ylabel('time[min]')

    ax7 = fig1.add_subplot(224)
    ax7.plot(range(0, Y_predicted.shape[0]), Y_predicted[:, 15], 'o', label='yPredicted')
    ax7.plot(range(0, Y_simulated.shape[0]), Y_simulated[:, 15], 'o', label='ysimulated')
    plt.title('mean commuting distance')
    plt.ylabel('distance[m]')

    fig2 = plt.figure()
    manager = plt.get_current_fig_manager()
    manager.resize(*manager.window.maxsize())

    ax8 = fig2.add_subplot(221)
    ax8.plot(range(0, Y_predicted.shape[0]), Y_predicted[:, 16], 'o', label='yPredicted')
    ax8.plot(range(0, Y_simulated.shape[0]), Y_simulated[:, 16], 'o', label='ysimulated')
    plt.title('Volpe occupancy')
    plt.ylabel('[%]')

    fig1.savefig(nameGraph2)
    plt.show()

    fig2.savefig(nameGraph3)
    plt.show()

    print("R2 score final " + str(R2))
    errors = R_squaredText(Y_predicted,Y_simulated)
    return errors

def printTheEnd():
    print("END")

for rndseedValue in range(0,max_seedValue):
    random.seed(rndseedValue)
    importedData = np.loadtxt(open(nameFileIN, "rb"), delimiter=",")

    for i in range(50): #Shuffle Data 50 times
        np.random.shuffle(importedData)

    list = importedData[:,0]
    maxValue = max(list)
    minValue = min(list)

    for i in range(0,100):
        importedData[i,0] = (importedData[i,0]-minValue)/(maxValue-minValue)
    index = int(round(importedData.shape[0]*0.8))


    train_features0 = importedData[0:index,0:2]
    train_results0 = importedData[0:index,2:19]
    test_features0 = importedData[index:importedData.shape[0],0:2]
    test_results0 = importedData[index:importedData.shape[0],2:19]

    cont = 0
    mat = np.zeros((5670, 2))
    # mat[0,:] = importedDataRaw[0,0:1] #first case (current non-built situation)
    for price in arange(0, 1.05, 0.05):
        for area in range(10000, 2710000, 10000):
            mat[cont, 0] = (area - minValue) / (maxValue - minValue)
            mat[cont, 1] = price
            #mat[cont, 2] = area
            cont = cont + 1

    R2_value, results_mas, test_predicted = predictions(train_features0, train_results0, test_features0, test_results0, mat)

    if R2_value > R2_final:
        R2_final = R2_value
        results_mas_final = results_mas
        test_simulated_final = test_results0
        test_predicted_final = test_predicted

errors = showGraphs(R2_final,test_simulated_final,test_predicted_final)

for i in range(0,5670):
    mat[i,0] = mat[i,0]*(maxValue - minValue) + minValue

results_allcolumns = np.concatenate((mat,results_mas_final),axis=1)
firstlineRaw = importedDataRaw[0,:]

results_allrows = np.zeros((5671,19))

for i in range(0,5671):
    if i == 0:
        results_allrows[i,:] = firstlineRaw[:]
    else:
        results_allrows[i,:] = results_allcolumns[i-1,:]

savetxt(nameFileOUT, results_allrows, delimiter=",")
savetxt(nameStatFile, errors, delimiter=",")


